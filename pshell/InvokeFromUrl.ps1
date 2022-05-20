$Uri = "https://raw.githubusercontent.com/spottsmorpheus/tools/main/pshell/contextinfo.ps1"
$Name = "ContextInfo"

# Load Powershell code from GitHub Uri and invoke as a temporary Module
$Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
if ($Response.StatusCode -eq 200) {
    New-Module -Name $Name -ScriptBlock ([ScriptBlock]::Create($Response.Content))
}

# This should have created a Dynamic Module for use in this Scipt

# If a Morpheus variable is set to a nul value this is what Morpheus will return.
# you should test this string for a null value
$morpheusNull = "null"

# Morpheus Variables - These are replace by Morpheus 
$morpheus = [PSCustomObject]@{
  instanceName = "<%= instance.name%>";
  serverName = "<%= server.name%>";
  context="Not Set";
  taskInfo = "Windows Boilerplate Task Information";
}

if ($morpheus.InstanceName.trim() -eq $morpheusNull) {
  $morpheus.context = "Server"
} else {
  $morpheus.context = "Instance"
}

# a small wait can be useful
start-sleep 5

# Now call the Get-TaskInfo from the Module loaded from Git - Pass in the Morpheus variables
$json = Get-TaskInfo -morpheus $morpheus -AsJson
#Return the data to Morpheus as a json document
$json 