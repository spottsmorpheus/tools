# Scipt scoped variables for Appliance and Token
# Use the functions Set-MorpheusAppliance and Set-MorpheusToken and Set-MorpheusSkipCert to change

$Appliance =  "Use Set-MorpheusAppliance to set Appliance URL"
$Token = "Use Set-MorpheusToken so set the bearer token"
$SkipCert = $false
$SkipCertSupported = ($Host.Version.Major -ge 6)

#Type Declaration for overriding Certs on Windows system
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


Write-Host "Powershell Host Version: $($Host.Version.ToString())"
Write-Host "Morpheus API Powershell Functions" -ForegroundColor Green
Write-Host "Use Set-MorpheusAppliance to set Appliance URL" -ForegroundColor Green
Write-Host "Use Set-MorpheusToken so set the bearer token" -ForegroundColor Green
Write-Warning "Use of -SkipCertificateCheck on Invoke-WebRequest is $(if($SkipCertSupported){'Supported'}else{'Not Supported'})"

Write-Host "Use Set-MorpheusSkipCert to Skip Certificate Checking for Self-Signed certs" -ForegroundColor Green


function Get-MorpheusVariables {
    <#
    .SYNOPSIS
    Displays the Morpheus Script variables

    .DESCRIPTION
    Displays the Morpheus Script variables

    Examples:
    Get-MorpheusVariables

    .OUTPUTS
    The Morpheus Script level variables
    #>     
    Write-Host "Appliance = $($Script:Appliance)" -ForegroundColor Cyan
    Write-Host "Token     = $($Script:Token)" -ForegroundColor Cyan
    Write-Host "SkipCert  = $($Script:SkipCert)" -ForegroundColor Cyan
}

function Set-MorpheusAppliance {
    <#
    .SYNOPSIS
    Sets the Morpheus Appliance URL

    .DESCRIPTION
    Sets the Morpheus Appliance URL

    Examples:
    Set-MorpheusAppliance -Appliance "https:\\myappliance.com"

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

function Set-MorpheusToken {
    <#
    .SYNOPSIS
    Sets the Morpheus API Token

    .DESCRIPTION
    Sets the Morpheus API token for use in this Powershell session

    Examples:
    Set-MorpheusToken -Token <MorpheusApiToken>

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
function Set-MorpheusSkipCert {
    <#
    .SYNOPSIS
    Sets the API Calls to ignore Certificate checking

    .DESCRIPTION
    Sets the Morpheus API Calls to ignore Certificate checking

    Examples:
    Set-MorpheusSkipCert

    .OUTPUTS
    None (sets Script level Variable $SkipCert)
    #>
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
        # Ignore Self Signed SSL via a custom type
        Add-Type $script:certCallback
    }
    # Ignore Self Signed Certs
    [ServerCertificateValidationCallback]::Ignore()
    # Accept TLS 1, 1.1 and 1.2 versions
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
    $Script:SkipCert = $true

}

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
    write-host "Invoking Api $($uri)" -ForegroundColor Green
    try {
        if ($script:SkipCertSupported) {
            $Response = Invoke-WebRequest -SkipCertificateCheck:$script:SkipCert -Method POST -Uri $uri -Body $body -ContentType "application/x-www-form-urlencoded"
        } else {
            $Response = Invoke-WebRequest -Method POST -Uri $uri -Body $body -ContentType "application/x-www-form-urlencoded"
        }
        if ($Response.StatusCode -eq 200) {
            $Payload = $Response.content | Convertfrom-Json
            return $Payload.access_token
        } else {
            Write-Warning "Response StatusCode $($Response.StatusCode)"
            return $null
        }
    }
    catch {
        Write-Error "Error calling Api ($_)"
        return $null
    }
}

function Invoke-MorpheusApi {
    <#
    .SYNOPSIS
    Invokes the Morpheus API call 

    .DESCRIPTION
    Invokes a Morpheus API call for the supplied EndPoint parameter. 

    Examples:
    Invoke-MoprheusApi -EndPoint "/api/whoami"

    .PARAMETER Appliance
    Appliance URL - Defaults to the Script level variable set by Set-MorpheusAppliance

    .PARAMETER Token
    Token - Defaults to the Script level variable set by Set-MorpheusToken

    .PARAMETER EndPoint
    API Endpint - The api endpoint and query parameters

    .PARAMETER Method
    Method - Defaults to GET

    .PARAMETER PageSize
    If the API enpoint supports paging, this parameter sets the size (max API parameter). Defaults to 25

    .PARAMETER Body
    If required the Body to be sent as payload

    .PARAMETER SkipCert
    Defaults to the Script level variable set by Set-MorpheusSkipCert. True or False if Certificate checking is ignored

    .OUTPUTS
    [PSCustomObject] API response

    #>      
    [CmdletBinding()]
    param (
        [string]$Endpoint="api/whoami",
        [string]$Method="Get",
        [string]$Appliance=$script:Appliance,
        [string]$Token=$script:Token,
        [int]$PageSize=25,
        [PSCustomObject]$Body=$null
    )

    Write-Host "Using Appliance $($Appliance) :SkipCert $($Script:SkipCert)" -ForegroundColor Green
    if ($Endpoint[0] -ne "/") {$Endpoint = "/" + $Endpoint}

    $Headers = @{"Authorization" = "Bearer $($Token)"; "Content-Type" = "application/json"}

    if ($Body -Or $Method -ne "Get" ) {
        Write-Host "Method $Method : Endpoint $EndPoint" -ForegroundColor Green
        try {
            # Body Object detected - convert to json payload for the Api (5 levels max)
            $Payload = $Body | Convertto-json -depth 5
            if ($script:SkipCertSupported) {
                $Response=Invoke-WebRequest -Method $Method -Uri "$($Appliance)$($Endpoint)" -Body $Payload -Headers $Headers -SkipCertificateCheck:$script:SkipCert -ErrorAction SilentlyContinue
            } else {
                $Response=Invoke-WebRequest -Method $Method -Uri "$($Appliance)$($Endpoint)" -Body $Payload -Headers $Headers -ErrorAction SilentlyContinue 
            }
            if ($Response.StatusCode -eq 200) {
                Write-Host "Success:" -ForegroundColor Green
                $Payload = $Response.Content | Convertfrom-Json
                return $Payload
            } else {
                Write-Warning "API returned status code $($Response.StatusCode)"
            }
        } catch {
            Write-Error "Error calling Api ($_)"
            return $null
        }    
    } else {
        # Is this for a GET request with no Body - if so prepare to page if necessary
        $Page = 0
        $More = $true
        $Data = $null
        $Total = $null

        Write-Host "Method $Method : Paging in chunks of $PageSize" -ForegroundColor Green

        do {
            if ($Endpoint -match "\?") {
                $Url = "$($Appliance)$($Endpoint)&offset=$($Page)&max=$($PageSize)"
            } else {
                $Url = "$($Appliance)$($Endpoint)?offset=$($Page)&max=$($PageSize)"
            }
            Write-Host "Requesting $($Url)" -ForegroundColor Green
            Write-Host "Page: $Page - $($Page+$PageSize) $(if ($Total) {"of $Total"})" -ForegroundColor Green

            try {
                if ($script:SkipCertSupported) {
                    $Response=Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -ErrorAction SilentlyContinue -SkipCertificateCheck:$script:SkipCert
                } else {
                    $Response=Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -ErrorAction SilentlyContinue 
                }
                if ($Response.StatusCode -eq 200) {
                    # OK Response - Convert payload from json
                    $Payload = $Response.Content | Convertfrom-Json
                    if ($Payload.meta) {
                        # Pagable response
                        $Total = [Int32]$Payload.meta.total
                        $Size = [Int32]$Payload.meta.size
                        $Offset = [Int32]$Payload.meta.offset
                        #Response is capable of being paged and contains a meta property. Extract Payload
                        $PayloadProperty = $Payload.PSObject.Properties | Where-Object {$_.name -notmatch "meta"} | Select-Object -First 1
                        $PropertyName = $PayloadProperty.name
                        if ($Null -eq $Data) {
                            # Return the data as PSCustomObject containing the required property
                            $Data = [PSCustomObject]@{$PropertyName=$Payload.$PropertyName}
                        } else {
                            $Data.$PropertyName += $Payload.$PropertyName
                        }
                        $More = (($Offset + $Size) -lt $Total)
                        $Page = $Offset + $Size
                    } else {
                        # Non-Pagable. Return whole response
                        Write-Host "Returning complete Payload" -ForegroundColor Green
                        $More = $false
                        $Data = $Payload
                    }
                    
                } else {
                    Write-Warning "API returned status code $($Response.StatusCode)"
                }
                # Should have a response

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
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?instanceId=$($InstanceId)" 
    } elseif ($ServerId -ne 0) {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?serverId=$($ServerId)" 
    } else {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?refType=container" 
    }
    # Filter By ProcessType
    return $proc.processes| Where-Object {$_.processType.code -eq $ProcessType}
}

function Get-MorpheusLogs {
    param (
        [Object]$Start=$null,
        [Object]$End=$null
    )

    if ($Start -And $End) {
        try {
            if ($Start.GetType().name -eq "DateTime") {
                $Start = $Start.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            } else {
                $Start = [datetime]::parse($Start).toUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        } Catch {
            Write-Error "Incorrect Time Format $Start"
            return
        }
        try {
            if ($End.GetType().name -eq "DateTime") {
                $End = $End.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            } else {
                $End = [datetime]::parse($End).toUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        } Catch {
            Write-Error "Incorrect Time Format $End"
            return
        }       
        Write-Host "Filtering Health Logs: Start $($Start)  - End $($End)"
        $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs?startDate=$($Start)&endDate=$($End)" 
        $Log = $Response.logs 
        return $Log
    } else {
        $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs" -PageSize 1000
        $Log = $Response.logs 
        return $Log     
    }
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
            if ($childEvent.startDate -AND $childEvent.endDate) {
                Get-MorpheusLogs -Start $childEvent.startDate -End $childEvent.endDate | Sort-Object -prop seq | 
                    Select-Object -Property @{Name="Event";Expression={$event.processType.name}}, @{Name="childEvent";Expression={$childEvent.processType.name}},hostname,seq,@{Name="TimeStampUTC";Expression={$_.ts}},level,message
            }
        } 
    }
    if ($AsJson) {
        return $provisionLogs | ConvertTo-Json -Depth 5
    } else {
        return $provisionLogs
    }
}

Function Show-RoleFeaturePermissions {
    [CmdletBinding()]

    $Roles = Invoke-MorpheusApi -Endpoint "/api/roles"
    $UserRoles = $Roles.roles | Where-Object {$_.scope -eq "Account" -And $_.roleType -eq "user"} 
    $RoleData = $UserRoles | ForEach-Object {Invoke-MorpheusApi -Endpoint "/api/roles/$($_.id)"}
    $features = foreach ($role in $RoleData) {
        $Role.featurePermissions | Select-Object -Property @{n="authority";e={$Role.role.authority}},code,name,access
        #$Role.InstanceTypePermissions | Select-Object -Property @{n="authority";e={$Role.role.authority}},code,name,access
    }

    $FeaturePermissionsMatrix=[System.Collections.Generic.List[PSCustomObject]]::new()
    $FeaturePermissions = $features | Group-Object -Property code
    foreach ($f in $FeaturePermissions) {
        $permission = [PSCustomObject]@{feature=$f.name}
        $f.Group | ForEach-Object {Add-Member -InputObject $permission -MemberType NoteProperty -Name $_.authority -Value $_.access}
        $FeaturePermissionsMatrix.Add($Permission)
    }
    $FeaturePermissionsMatrix

}