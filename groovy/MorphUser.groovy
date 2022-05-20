import grails.gorm.transactions.Transactional
import groovy.text.SimpleTemplateEngine
import org.apache.directory.groovyldap.LDAP
import org.apache.directory.groovyldap.SearchScope
import static groovy.json.JsonOutput.*
import com.bertramlabs.plugins.*

// Morpheus Methods

private getConnection(params, noBindingUser = false) {
		
    println('buildContextProperties') 
    def userSource = params.userSource
    
	// this stuff should be collected from a custom LDAP settings UI
	// saved settings can be overridden by passing in the params
	def useSSL = ['on','true'].contains((params.useSSL ?: userSource?.getConfigMap()?.useSSL)?.toString())
		def ldapUrl = (useSSL ? 'ldaps://' : 'ldap://') + userSource?.getConfigMap()?.url
	// use specified username and password or use configured binding username and password
	def bindingUsername = (noBindingUser ? params.username : userSource?.getConfigMap()?.bindingUsername)+'@'+userSource.getConfigMap().domain
	def bindingPassword = noBindingUser ? params.password : userSource?.getConfigMap()?.bindingPassword

	com.morpheus.util.SSLUtility.trustSelfSignedSSL()
	return LDAP.newInstance(ldapUrl, bindingUsername, bindingPassword)
}

private getUser(params) {
    def userSource = params.userSource
    params.adLdap = params.adLdap ?: getConnection(params) // use interactive user to auth to ldap
    def rtn
    if (!params.userFqn) {
        
        def domain = userSource.getConfigMap().domain//params.username.split('@')[1]
        //def domain = (params.username ?: userSource?.getConfigMap()?.bindingUsername).split('@')[1]
        String escapedUsername = params.username.replaceAll(/([\[\]:;\|\=\+\*\?\<\>\\\/])/,'\\\\$1')
        def results = params.adLdap.search('(&(objectClass=user)(sAMAccountName='+escapedUsername+'))', buildDomainQuery(domain),  SearchScope.SUB )
        results?.each {usr->
            rtn = usr
        }
        params.userFqn = rtn?.distinguishedName
    }
    rtn = params.adLdap.read(params.userFqn)
    rtn
}
    
private buildDomainQuery(domain) {
    def q = domain.tokenize('.').collect{'DC='+it}.join(',')
    q
}

// Start Here

// Need this map for calling Morpheus Methods
def params = [:]

// Will be done via customOptions
def suppliedUser = customOptions?.user ? customOptions.user : "spmorphadmin"
def suppliedPassword = "St1ngray%"

params.username = suppliedUser
params.password = suppliedPassword

println("Username from Options ${suppliedUser}")

if (suppliedUser.indexOf('\\') > 0) {
    // Was an account (Tenant) Specified?
    def parts = suppliedUser.tokenize('\\')
    userAccount = Account.findBySubdomainAndActive(parts[0],true)
	newUser = parts[1]
	if (!userAccount && parts[0].isLong()) userAccount = Account.findByIdAndActive(new Long(parts[0]),true)
    if (!userAccount) userAccount = Account.findByMasterAccount(true)
}
else {
    // Use Master Account
    userAccount = Account.findByMasterAccount(true)
    newUser = suppliedUser
}

// newUser is userId to look up
println("Supplied Username ${suppliedUser} : Tenant Account=${userAccount?.name} User=${newUser}")
println("")
// 2 items 
// newUser a string containing UserName
// userAccount Account object containin the Tenant 

//Get UserSource (Probably pass this in a CustomOption)
userSource = UserSource.findByAccountAndActive(userAccount,true)

if (userSource) {
    params.userSource = userSource
    println("UserSource found ${userSource.id} ${userSource.name}")
	println(prettyPrint(toJson(userSource.getConfigMap())))
    // Create an instance of the LDAP class
    try {
        // Bind to usersource - true parameter means use passed credentials (but does not actually connect)
        def ldapVar = getConnection(params, true)
        if (ldapVar) {
            println("Connected to LDAP")
            params.adLdap = ldapVar
            // Now it connects 
            def dn = getUser(params)
            println(dn)
            
        }
    } catch (Exception ex) {
        println("Exception Raised logging in")
        println(ex)
    }   
} else {
    println("WARNING - No valid UserSource found")
}




