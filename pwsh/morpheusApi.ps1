
$Appliance =  ""
$Token = ""

<#
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    # Ignore Self Signed SSL via a custom type

    Add-Type $certCallback
}
#>

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
#[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12


function get-token {
    param (
        [string]$appliance=$script:Appliance,
        [PSCredential]$credential=$null
    )

    #Credentials can be for Subtenants an if so they are in the form Domain\User where Domain is the Tenant Number 
    if (-Not $credential) {
        $credential = get-credential -message "Enter Morpheus UI Credentials"
    }
    $body = @{username="";password=""}
    $body.username=$credential.username
    $body.password=$credential.getnetworkcredential().password
    $uri = "$($appliance)/oauth/token?grant_type=password&scope=write&client_id=morph-api"
    write-host $uri
    $token = Invoke-RestMethod -SkipCertificateCheck -Method POST -uri $uri -body $body
    return $token.access_token
}


#$token = get-token -Appliance $Ml7App

#$headers = @{Authorization = "Bearer $($token.access_token)"}

function Get-Api {
    param (
        [string]$Appliance=$script:Appliance,
        [string]$Token=$script:Token,
        [string]$Endpoint
    )

    Write-Host "Using Appliance $($Appliance) with Token $Token"
    $Headers = @{Authorization = "Bearer $($Token)"}
    $Response=Invoke-RestMethod -Method GET -Uri "$($Appliance)/$($Endpoint)" -Headers $headers -SkipCertificateCheck 
    return $Response
}

function Set-Appliance {
    param (
        [string]$Appliance
    )
    
    $script:Appliance = $Appliance
    Write-Host "Default Appliance Host set to $Appliance"
}

function Set-Token {
    param (
        [string]$Token
    )
    
    $script:Token = $Token
    Write-Host "Default Token set to $Token" 
}
