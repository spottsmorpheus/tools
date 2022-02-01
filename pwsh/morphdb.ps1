
$TableInfoQuery = @"
select
    table_name,column_name,referenced_table_name,referenced_column_name
from
    information_schema.key_column_usage
where
    table_schema = 'morpheus' 
    and table_name = '%%Table%%'
"@

$Constraints = @"
select 
   K.CONSTRAINT_NAME, K.TABLE_NAME, K.COLUMN_NAME, K.REFERENCED_TABLE_NAME, K.REFERENCED_COLUMN_NAME
from 
   INFORMATION_SCHEMA.KEY_COLUMN_USAGE K 
where K.CONSTRAINT_SCHEMA='morpheus' and (K.TABLE_NAME like '{0}' or K.REFERENCED_TABLE_NAME like '{0}');
"@

function Get-TableInfo {
    param (
        [string]$Table
    )

    $q = $Constraints -f $Table
    return $q
}


Import-Module -Name SimplySQL -ErrorAction SilentlyContinue
if (-NOT $?) {
    Write-Host "Script requires the SimplySQL module from Powershell Gallery"
    Write-Host ""
    Write-Host "Use Import-Module -Name SimplySql to install"
    exit 1
}
$secretsFile=Invoke-Expression "sudo cat /etc/morpheus/morpheus-secrets.json" 
if ($secretsFile) {
    $secrets = $secretsFile | ConvertFrom-Json
    # Define clear text string for username and password
    $dbUser = "morpheus"

    # Convert to SecureString
    $secPwd = ConvertTo-SecureString $secrets.mysql.morpheus_password -AsPlainText -Force
    $dbCred = New-Object System.Management.Automation.PSCredential ($dbUser, $secPwd)

    Open-MySqlConnection -Server 127.0.0.1 -Credential $dbCred -Database "morpheus"
    Get-SqlConnection
}
else {
    Write-Host "Cannot find Secrets file. Are you running on Morpheus Appliance?"
    exit 1
}


