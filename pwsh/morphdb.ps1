# Script wide constants/here srtrings

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

    $Query = $Script:Constraints -f $Table
    return $Query
}

Function Get-ProvisionHistory {
    param (
        [int32]$ServerId=0
    )

    $Q = "select display_name,ref_type,process_type_name,timer_category,timer_sub_category,status, start_date, end_date,instance_id,container_id,server_id from process_event"
    if ($ServerId -eq 0) {
        $History=invoke-SQLQuery -Query ($Q + " where ref_type='container'") 
    } else {
        $History=invoke-SQLQuery -Query ($Q + " where server_id=$($ServerId)")
    }
    $History
}


Import-Module -Name SimplySQL -ErrorAction SilentlyContinue
if (-NOT $?) {
    Write-Host "Script requires the SimplySQL module from Powershell Gallery"
    Write-Host ""
    Write-Host "Use Install-Module -Name SimplySql to install"
    exit 1
}

# Read the secrets file on and All-In-1 Appliance
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


