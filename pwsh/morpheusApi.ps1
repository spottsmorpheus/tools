# Scipt scoped variables for Appliance and Token
# Use the functions Set-Appliance and Set-Token to define

$Appliance =  ""
$Token = ""

# to get a date in iso format use .ToString("s") on the date object

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


function Get-MorpheusApiToken {
    <#
    .SYNOPSIS
    Gets the Morpheus API token for the User Credentials supplied

    .DESCRIPTION
    Gets the Morpheus API token for the User Credentials supplied

    Examples:
    Get-MorpheusApiToken -Appliance <MorpheusApplianceURL> -Credential <PSCredentialObject>

    .PARAMETER Appliance
    Appliance Name - Defaults to the Script level variable set by Set-Appliance

    .PARAMETER Credential
    PSCredential Object - if missing Credentials will be prompted for

    .OUTPUTS
    Token : Outputs the API Token

    #>    
    param (
        [string]$appliance=$script:Appliance,
        [PSCredential]$credential=$null
    )

    #Credentials can be for Subtenants and if so they are in the form Domain\User where Domain is the Tenant Number 
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

function Invoke-MorpheusApi {
    [CmdletBinding()]
    param (
        [string]$Method="GET",
        [string]$Appliance=$script:Appliance,
        [string]$Token=$script:Token,
        [string]$Endpoint="api/whoami",
        [int]$PageSize=25,
        [PSCustomObject]$Body=$null,
        [switch]$SkipCert

    )

    Write-Host "Using Appliance $($Appliance) with Token $Token"
    Write-Host "Method $Method : Paging in chunks of $PageSize"

    if ($Endpoint[0] -ne "/") {$Endpoint = "/" + $Endpoint}

    $Headers = @{Authorization = "Bearer $($Token)"}

    if ($Body -Or $Method -ne "GET" ) {
        try {
            if ($SkipCert) {
                $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)$($Endpoint)" -Body $Body -Headers $Headers -SkipCertificateCheck -ErrorAction SilentlyContinue
            } else {
                $Response=Invoke-RestMethod -Method $Method -Uri "$($Appliance)$($Endpoint)" -Body $Body -Headers $Headers -ErrorAction SilentlyContinue 
            }
            $Data = $Response
        } catch {
            Write-Warning "No Response Payload for endpoint $($Endpoint)"
            $Data = $Null
        }    
    } else {
        # Is this for a GET request with no Body - if so prepare to page if necessary
        $Page = 0
        $More = $true
        $Data = $null
        $Total = $null

        do {
            if ($Endpoint -match "\?") {
                $Url = "$($Appliance)$($Endpoint)&offset=$($Page)&max=$($PageSize)"
            } else {
                $Url = "$($Appliance)$($Endpoint)?offset=$($Page)&max=$($PageSize)"
            }
            Write-Host "Requesting $($Url)" -ForegroundColor Green
            Write-Host "Page: $Page - $($Page+$PageSize) $(if ($Total) {"of $Total"})" -ForegroundColor Green

            try {
                if ($SkipCert) {
                    $Response=Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ErrorAction SilentlyContinue -SkipCertificateCheck
                } else {
                    $Response=Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ErrorAction SilentlyContinue 
                }
                # Should have a response
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
                    $Page = $Offset + $Size
                } else {
                    # Non-Pagable. Return whole response
                    Write-Host "Returning complete Payload" -ForegroundColor Green
                    $More = $false
                    $Data = $Response
                }
            } catch {
                Write-Warning "No Response Payload for endpoint $($Url)"
                $More = $False
            }
        } While ($More)
    }    
    return $Data
}


function Get-ProvisionEvents {
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [string]$ProcessType="provision"
    )

    if ($InstanceId -ne 0) {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?instanceId=$($InstanceId)" -SkipCert
    } elseif ($ServerId -ne 0) {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?serverId=$($ServerId)" -SkipCert
    } else {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?refType=container" -SkipCert
    }
    # Filter By ProcessType
    return $proc.processes| Where-Object {$_.processType.code -eq $ProcessType}
}

function Get-MorpheusLogs {
    param (
        [DateTime]$Start=[DateTime]::Now.toUniversalTime().AddHours(-1),
        [DateTime]$End=[DateTime]::Now.toUniversalTime()
    )

    Write-Host "Start $($Start.ToString("s"))  - End $($End.ToString("s"))"
    $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs?startDate=$($Start.ToString("s"))&endDate=$($End.ToString("s"))" -SkipCert
    $Log = $Response.logs 
    return $Log
}

function get-ProvisionEventLogs {
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [switch]$AsJson
    ) 

    $provisionEvents =  Get-ProvisionEvents -InstanceId $InstanceId -ServerId $ServerId
    
    $provisionLogs = foreach ($event in $provisionEvents) {
        foreach ($childEvent in $event.events) {
            Write-Host "Grabbing Logs for Event $($event) - $($childEvent)" -ForegroundColor Green
            Get-MorpheusLogs -Start $childEvent.startDate -End $childEvent.endDate | Sort-Object -prop seq | 
            Select-Object -Property @{Name="Event";Expression={$event.processType.name}}, @{Name="childEvent";Expression={$childEvent.processType.name}},hostname,seq,ts,level,message
        } 
    }
    if ($AsJson) {
        return $provisionLogs | ConvertTo-Json -Depth 5
    } else {
        return $provisionLogs
    }
}

function Set-Appliance {
    <#
    .SYNOPSIS
    Sets the Morpheus Appliance URL

    .DESCRIPTION
    Sets the Morpheus Appliance URL

    Examples:
    Set-Appliance -Appliance "https:\\myappliance.com"

    .PARAMETER Appliance
    Appliance URL

    .OUTPUTS
    None (sets a Script level Variable $Appliance)
    #>    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Appliance
    )
    
    $script:Appliance = $Appliance
    Write-Host "Default Appliance Host set to $Appliance"
}

function Set-Token {
    <#
    .SYNOPSIS
    Sets the Morpheus API Token

    .DESCRIPTION
    Sets the Morpheus API token for use in this Powershell session

    Examples:
    Set-Token -Token <MorpheusApiToken>

    .PARAMETER Name
    Bearer Token

    .OUTPUTS
    None (sets Script level Variable $Token)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Token     
    )
    
    $script:Token = $Token
    Write-Host "Default Token set to $Token"
}