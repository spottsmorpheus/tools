Function Find-ADObject
<#
.SYNOPSIS
Search AD via Global Catalog for objects matching Name

.DESCRIPTION
Searchh for object of the ObjectClass specified where cn or SAMAccountname match Name
Wildcards are allowed in Name

Examples:
Find-ADObject -Name Kvtl* -Objecttype User

.PARAMETER Name
Object name used to match cn or SAMAccountName attributes

.PARAMETER ObjectType
User (Default) Group or Computer

.PARAMETER $Forest
Forest name in Dns format (ie medimmune.com)

.OUTPUTS
[DirectoryEntry] LDAP objects matching

#>
{
	[CmdletBinding()]
	Param 
	(
		[Parameter(Position=0,Mandatory=$true)] [String]$Name,
		[ValidateSet("User","Computer","Group")][String]$ObjectType="User",
		[String]$Forest
	)

	if ($Forest)
	{
		$ForestRoot = [String]::Join(",",$($forest.Split(".") | % {"DC="+$_}))
	}
	else
	{
		$ForestRoot = ([ADSI]"LDAP://RootDSE").rootDomainNamingContext
	}
	#Global Catalog Search
	$Searchroot = new-object System.DirectoryServices.DirectoryEntry("GC://" +$ForestRoot)
	$filter="(&(objectclass=$ObjectType)(|(cn=$Name)(SAMAccountName=$Name)))"
	$props = @("distinguishedName","SAMAccountName")
	$Searcher = new-Object System.DirectoryServices.DirectorySearcher($Searchroot,$filter,$props)
	$GCObj = $Searcher.FindAll()
	if ($GCObj)
	{
		$ADObj = $GCObj | Foreach-Object {[ADSI]"LDAP://$($_.Properties.distinguishedname)"}
	}
	else
	{
		$ADObj = $Null
	}
	$ADObj	
} # End Of Find-ADObject
