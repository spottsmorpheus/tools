# Look specifically for Windows Security Events connected with Morpheus
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
                    RecordId         = $Event.RecordId;
                    TimeCreated      = $Event.TimeCreated.ToString("s");
                    Id               = $Event.Id;
                    MachineName      = $Event.MachineName;
                    TargetUserName   = $EventData.TargetUserName;
                    TargetDomainName = $EventData.TargetDomainName;
                    IpAddress        = $EventData.IpAddress;
                    IpPort           = $EventData.IpPort
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


