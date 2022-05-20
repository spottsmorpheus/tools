# Look specifically for Windows Security Events connected with Morpheus
function Get-MorpheusAuditEvents {
    param (
        [int32]$RecentMinutes=10,
        [String]$Computer="",
        [String]$MorpheusIPAddress,
        [Switch]$AsXML,
        [Switch]$AsSummary
    )

    # Setup the xPath Query for fast filtering of EventLog

    #Filter the Event\System Node for EventId's and TimeCreated 
    $xSysFilter = "TimeCreated[@SystemTime>'{0}'] and (EventID=4625 or EventID=4624)" -f [datetime]::Now.AddMinutes(-1*$RecentMinutes).ToUniversalTime().ToString('s')

    if ($MorpheusIPAddress) {
        #Filter the EventData node for <Data Name="Ipaddress">MorpheusIPAddress</Data>
        $xEventDataFilter = "[EventData[Data[@Name='IPAddress']='{0}']]" -f $MorpheusIPAddress
    } else {
        $xEventDataFilter = ""
    }
    
    # Construct the xPath filter
    $xPath="Event[System[{0}]]{1}" -f $xSysFilter,$xEventDataFilter
    Write-Host "Using xPath Filter $($xPath)" -ForegroundColor Green

    # Get Events using the xPath filter
    if ($Computer) {
        $Events = Get-WinEvent -LogName security -ComputerName $Computer -FilterXPath $xpath
    } else {
        $Events = Get-WinEvent -LogName security -FilterXPath $xpath
    }

    if ($AsXML) {
        $XMLEvents = $Events | Foreach-Object {XmlPrettyPrint -Xml $_.toXML()}
        return $XMLEvents
    } elseif ($AsSummary) {           
        $Summary = foreach ($Event in $Events) {
            $EventData = Get-EventdataProperties -Event $Event
            [PSCustomObject]@{
                TimeCreated = $Event.TimeCreated;
                Id = $event.Id;
                TargetUserName=$EventData.item("TargetUserName");
                IpAddress=$EventData.item("IpAddress");
                IpPort=$EventData.item("IpPort")
            }
        }
        return $Summary
    } else {
        return $Events
    }
} 

Function XmlPrettyPrint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position=0)]
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
        [Parameter(Mandatory = $true, Position=0)]
        $Event
    )

    [XML]$EventXML = $Event.toXML()
    $EventData = @{}
    if ($EventXML.Event.EventData) {
        $EventXML.Event.EventData.Data | Foreach-Object {$EventData.Add($_.name,$_.'#text')}
    }
    return $EventData
}