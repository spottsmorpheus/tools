# Create a Powershell (Windows and Powershell Core)
# HereString for Profile Contents

$ProfileScript = @'
# Powershell Profile

# Do not Modify this Section

Function Invokefrom-GitHub {
    [CmdletBinding()]
    Param (
        [String]$ScriptUrl="",
        [String]$Name=""
    )
    if ($ScriptUrl) {

        $Response = Invoke-WebRequest -Uri $ScriptUrl -UseBasicParsing
        if ($Response.StatusCode -eq 200) {
            New-Module -Name $Name -ScriptBlock ([ScriptBlock]::Create($Response.Content))
        }
    } else {
        Write-Warning "Cannot locate Url '$ScriptUrl"
    }
}

Write-Host "Loading Powershell Profile and Tools directly from GitHub"
Write-Host ""
Invokefrom-GitHub -ScriptUrl "https://raw.githubusercontent.com/spottsmorpheus/tools/main/pwsh/morpheusApi.ps1" -Name "Morpheus-Api"
Invokefrom-GitHub -ScriptUrl "https://raw.githubusercontent.com/spottsmorpheus/tools/main/pwsh/outHTML.ps1" -Name "Out-HTML"

# You may add your own code here
# Set-MorpheusAppliance "Your Url"
# Set-MorpheusToten "YourToken"
# if you use self-signed certificates
# Set-MorpheusSkipCert 

'@

if (Test-Path $Profile) {
    #Powershell Profile Exists
    Write-Warning "A Powershell Profile Already Exists - Please Update profile manually and add the following ..."
    Write-Host $ProfileScript  -ForegroundColor Green
} else {
    New-Item -Path $Profile -Force
    Write-Host "Creating Powershell Profile" -ForegroundColor Green
    $ProfileScript | Set-Content -Path $Profile
}




