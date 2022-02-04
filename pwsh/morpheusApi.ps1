
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

# Investigating using Invoke-webrequest
function Invoke-MorpheusApi2 {
    param (
        [string]$Method="GET",
        [string]$Appliance=$script:Appliance,
        [string]$Token=$script:Token,
        [string]$Endpoint,
        [int]$Chunk=25,
        [string]$PropertyName="",
        [PSCustomObject]$Body=$null

    )

    Write-Host "Using Appliance $($Appliance) with Token $Token"
    write-Host "Method $Method : Paging in chunks $Chunk"
    $Headers = @{Authorization = "Bearer $($Token)"}
    if ($Body) {
        $R=Invoke-Webrequest -Method $Method -Uri "$($Appliance)/$($Endpoint)" -Body $Bbody -Headers $headers -SkipCertificateCheck
    } else {
        # Is this a GET request - if so prepare to page
        $Slice = 0
        $More = $true
        $Data = $Null
        do {
            Write-Host "Requesting Data $Slice :  $Chunk"
            $R=Invoke-WebRequest -Method $Method -Uri "$($Appliance)/$($Endpoint)?offset=$($Slice)&max=$($Chunk)" -Headers $headers -SkipCertificateCheck
            Write-Host "Status $($R.StatusCode) - content length $($R.RawContentLength)"
            $Response = $R.Content | Convertfrom-json -depth 10
            if ($Response.meta) {
                #Response is capable of being paged and contains a meta property
                if ($Null -eq $Data) {
                    # Return the data as PSCustomObject containing the required property
                    $Data = [PSCustomObject]@{$PropertyName=$Response.$PropertyName}
                } else {
                    $Data.$PropertyName += $Response.$PropertyName
                }
                $More = (($Response.meta.offset + $Response.meta.size) -lt $Response.meta.total)
                $slice = $Response.meta.offset + $Response.meta.size
            } else {
                $More = $false
                $Data = $Response
            }
        } While ($More)
    }  
    return $Data
}

function Invoke-MorpheusApi {
    param (
        [string]$Method="GET",
        [string]$Appliance=$script:Appliance,
        [string]$Token=$script:Token,
        [string]$Endpoint,
        [int]$Chunk=25,
        [PSCustomObject]$Body=$null,
        [switch]$SkipCert

    )

    Write-Host "Using Appliance $($Appliance) with Token $Token"
    write-Host "Method $Method : Paging in chunks $Chunk"
    $Headers = @{Authorization = "Bearer $($Token)"}
    if ($Body) {
        if ($SkipCert) {
            $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)/$($Endpoint)" -Body $Body -Headers -ErrorAction:SilentlyContinue $headers -SkipCertificateCheck
        } else {
            $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)/$($Endpoint)" -Body $Body -Headers $headers -ErrorAction:SilentlyContinue 
        }
        if (-Not $Response) {
            Write-Warning "No Response Payload for endpoint $($Endpoint)"
            $Data = $Null
        } else {
            $Data = $Response
        }     
    } else {
        # Is this a GET request - if so prepare to page
        $Slice = 0
        $More = $true
        $Data = $Null
        $Total = $Null
        do {
            Write-Host "Requesting Data: Slice $Slice - $($Slice+$Chunk) $(if ($Total) {"of $Total"})"
            if ($SkipCert) {
                $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)/$($Endpoint)?offset=$($Slice)&max=$($Chunk)" -Headers $headers -ErrorAction:SilentlyContinue -SkipCertificateCheck
            } else {
                $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)/$($Endpoint)?offset=$($Slice)&max=$($Chunk)" -Headers $headers -ErrorAction:SilentlyContinue 
            }
            if (-Not $Response) {
                Write-Warning "No Response Payload for endpoint $($Endpoint)"
                $More = $False
            } else {
                if ($Response.meta) {
                    # Pagable response
                    $Total = [Int32]$Response.meta.total
                    $Size = [Int32]$Response.meta.size
                    $Offset = [Int32]$Response.meta.offset
                    #Response is capable of being paged and contains a meta property. Extract Payload
                    $PayloadProperty = $Response.PSObject.Properties | Where-Object {$_.name -notmatch "meta"} | Select-Object -First 1
                    $PropertyName = $PayloadProperty.name
                    if ($Null -eq $Data) {
                        # Return the data as PSCustomObject containing the required property
                        $Data = [PSCustomObject]@{$PropertyName=$Response.$PropertyName}
                    } else {
                        $Data.$PropertyName += $Response.$PropertyName
                    }
                    $More = (($Offset + $Size) -lt $Total)
                    $Slice = $Offset + $Size
                } else {
                    # Non-Pagable. Return whole response
                    $More = $false
                    $Data = $Response
                }
            }
        } While ($More)
    }    
    return $Data
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