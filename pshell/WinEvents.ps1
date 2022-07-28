# Look specifically for Windows Security Events connected with Morpheus

$FailCodes = @{
    "0XC000005E"="There are currently no logon servers available to service the logon request.";
    "0xC0000064"="Misspelled or bad username";
    "0xC000006A"="Misspelled or bad password";
    "0XC000006D"="Bad username or authentication information";
    "0XC000006E"="Credentials OK but account restrictions prevent login";
    "0xC000006F"="User logon outside authorized hours";
    "0xC0000070"="User logon from unauthorized workstation";
    "0xC0000071"="User logon with expired password";
    "0xC0000072"="User Account disabled by administrator";
    "0XC00000DC"="Sam Server was in the wrong state to perform the desired operation.";
    "0XC0000133"="Clocks between DC and other computer too far out of sync";
    "0XC000015B"="The user has not been granted the requested logon type at this machine";
    "0XC000018C"="The logon request failed because the trust relationship between the primary domain and the trusted domain failed.";
    "0XC0000192"="An attempt was made to logon, but the Netlogon service was not started.";
    "0xC0000193"="User logon attempt with expired account.";
    "0XC0000224"="User is required to change password at next logon";
    "0XC0000225"="Evidently a bug in Windows and not a risk";
    "0xC0000234"="User logon attemot with account locked";
    "0XC00002EE"="Failure Reason: An Error occurred during Logon";
    "0XC0000413"="Logon Failure: The machine you are logging on to is protected by an authentication firewall. The specified account is not allowed to authenticate to the machine.";
    "0x0"="Status OK"
}


function Get-WindowsAuditEvents {
    param (
        [int32]$RecentMinutes = 10,
        [String]$Computer = "",
        [String]$IPAddress,
        [String]$TargetUser,
        [Switch]$AsXML,
        [Switch]$AsSummary,
        [Switch]$AsJson
    )

    # Setup the xPath Query for fast filtering of EventLog

    #Filter the Event\System Node for EventId's and TimeCreated 
    $xSysFilter = "TimeCreated[@SystemTime>'{0}'] and (EventID=4625 or EventID=4624)" -f [datetime]::Now.AddMinutes(-1 * $RecentMinutes).ToUniversalTime().ToString('s')

    if ($IPAddress -And $TargetUser) {
        $xEventDataFilter = "[EventData[Data[@Name='IPAddress']='{0}' or Data[@Name='TargetUserName']='{1}']]" -f $IPAddress, $TargetUser
    }
    elseif ($IPAddress) {
        #Filter the EventData node for <Data Name="Ipaddress">MorpheusIPAddress</Data>
        $xEventDataFilter = "[EventData[Data[@Name='IPAddress']='{0}']]" -f $IPAddress
    }
    elseif ($TargetUser) {
        #Filter the EventData node for <Data Name="Ipaddress">MorpheusIPAddress</Data>
        $xEventDataFilter = "[EventData[Data[@Name='TargetUserName']='{0}']]" -f $TargetUser
    }
    else {
        $xEventDataFilter = ""
    }
    
    # Construct the xPath filter
    $xPath = "Event[System[{0}]]{1}" -f $xSysFilter, $xEventDataFilter
    Write-Host "Using xPath Filter $($xPath)" -ForegroundColor Green

    # Get Events using the xPath filter
    if ($Computer) {
        $Events = Get-WinEvent -LogName security -ComputerName $Computer -FilterXPath $xpath -ErrorAction SilentlyContinue
    }
    else {
        $Events = Get-WinEvent -LogName security -FilterXPath $xpath -ErrorAction SilentlyContinue
    }
    if ($Events) {
        if ($AsXML) {
            $XMLEvents = $Events | Foreach-Object { XmlPrettyPrint -Xml $_.toXML() }
            return $XMLEvents
        }
        elseif ($AsSummary -Or $AsJson) {           
            $Summary = foreach ($Event in $Events) {
                $EventData = Get-EventdataProperties -Event $Event
                [PSCustomObject]@{
                    Audit            = if ($Event.Id -eq 4624) {"Success"} else {"Fail"};
                    RecordId         = $Event.RecordId;
                    TimeCreated      = $Event.TimeCreated.ToString("s");
                    Id               = $Event.Id;
                    MachineName      = $Event.MachineName;
                    TargetUserName   = $EventData.TargetUserName;
                    TargetDomainName = $EventData.TargetDomainName;
                    IpAddress        = $EventData.IpAddress;
                    IpPort           = $EventData.IpPort;
                    Status           = if ($Event.Id -eq 4625) {$Script:FailCodes.Item($EventData.Status)} else {"-"}
                    SubStatus        = if ($Event.Id -eq 4625) {$Script:FailCodes.Item($EventData.SubStatus)} else {"-"}
                }
            }
            if ($AsJson) {
                return $Summary | ConvertTo-Json -Depth 3
            } else {
                return $Summary
            }
        }
        else {
            return $Events
        }
    } else {
        Write-Warning "No Events match chosen criteria"
    }
} 


function Get-WindowsRestartEvents {
    [CmdletBinding()]
    param (
        [String]$Computer=$null,
        [ValidateSet("Hour","Day","Week","Month")]
        [String]$InLast="Day",
        [Switch]$AsJson
    )

    $now = Get-Date
    switch ($InLast) {
        "Hour" {$Start = $now.AddHours(-1)}
        "Day" {$Start = $now.AddDays(-1)}
        "Week" {$Start = $now.AddDays(-7)}
        "Month" {$Start = $now.AddMonths(-1)}
        default {$Start = $now.AddDays(-1)}
    }

    $EventProperties = @("RecordId",@{n="TimeCreated";e={$_.TimeCreated.ToString("s")}},"Id","MachineName","Message")
    if ($Computer) {
        $reboot=Get-WinEvent -ErrorAction "SilentlyContinue" -Computer $Computer -FilterHashtable @{ID=@(41,6005,6006,6008,6009,6011,1074,1076);logName="System";StartTime=$Start}
    } else {
        $reboot=Get-WinEvent -ErrorAction "SilentlyContinue" -FilterHashtable @{ID=@(41,6005,6006,6008,6009,6011,1074,1076);logName="System";StartTime=$Start}
    }
    if ($AsJson) {
       return $Reboot | Select-Object -Property $EventProperties | ConvertTo-Json -depth 3
    } else {
       return $reboot | Select-Object -Property $EventProperties
    } 
}


Function XmlPrettyPrint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Xml
    )

    # Read
    $stringReader = New-Object System.IO.StringReader($Xml)
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.CloseInput = $true
    $settings.IgnoreWhitespace = $true
    $reader = [System.Xml.XmlReader]::Create($stringReader, $settings)
   
    $stringWriter = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.CloseOutput = $true
    $settings.Indent = $true
    $writer = [System.Xml.XmlWriter]::Create($stringWriter, $settings)
   
    while (!$reader.EOF) {
        $writer.WriteNode($reader, $false)
    }
    $writer.Flush()
   
    $result = $stringWriter.ToString()
    $reader.Close()
    $writer.Close()
    $result
}


Function Get-EventdataProperties {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object[]]$Event
    )


    Begin {
        $EventData = [System.Collections.Generic.List[Object]]::new()
    }

    Process {
        foreach ($E in $Event) {
            [XML]$EventXML = $E.toXML()
            $EventProperties = [PSCustomObject]@{}
            if ($EventXML.Event.EventData) {
                $EventXML.Event.EventData.Data | 
                Foreach-Object { Add-Member -InputObject $EventProperties -MemberType NoteProperty -Name $_.name -Value $_.'#text' }
            }
            $EventData.Add($EventProperties)
        }

    }

    End {
        return $EventData
    }
}


