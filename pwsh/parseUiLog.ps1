# Function to read a Morpheus UI log file and consolidate output to make them more readable
Write-Host "Powershell Function to process Morpheus-UI log files. Note these must be the full UI logs"
Write-Host ""
Write-Host "To Use: `$LogData = Parse-MorpheusUiLog -FileName '<Path to file>'"

Function Parse-MorpheusUiLog {
    [CmdletBinding()]
    Param (
        [String]$LogFile,
        [Switch]$Clean,
        [Switch]$Consolidate,
        [String]$Start="",
        [String]$End="",
        [Int32]$Minutes=5
    )

    $tspattern="^([0-9-]+_[0-9:]+\.[0-9]*)"
    $logpattern = "^([0-9-]+_[0-9:]+\.[0-9]*).*(\[[0-9-:, ]*\])\s+(\[[a-zA-Z0-9-]*\])\s+([A-Z]*)\s+([a-zA-Z\.]*)"
    #ANSI Escape sequences
    $colorpattern = "\u001B[\[0-9;]*[a-zA-Z]"

    # Are we filtering by time?
    if ($Start) {
        try {
            $StartTime = [DateTime]::Parse($Start)
            Write-Host "Start Filter $($StartTime.ToString("s"))" -ForegroundColor Green
        } catch {
            Write-Error "Start Time in wrong format - use YYYY-MM-DDTHH:MM:SS (rfc1123)"
            return
        }        
        if ($End -eq "") {
            $EndTime = $StartTime.AddMinutes($Minutes)
            Write-Host "End Filter $($EndTime.ToString("s"))" -ForegroundColor Green
        } else {
            try {
                $EndTime = [DateTime]::Parse($End)
                Write-Host "End Filter $($EndTime.ToString("s"))" -ForegroundColor Green
            } catch {
                Write-Error "End Time in wrong format - use YYYY-MM-DDTHH:MM:SS (rfc1123)"
                return                
            }            
        }
    }
    
    # Log Metadata Object
    $LogMeta = [PSCustomObject]@{
        fileName = $LogFile;
        rawLines = 0;
        logEntries = 0;
        logStart = $null;
        logEnd = $null;
        filterStart=$null;
        filterEnd=$null
    }
    # Main Object - Returned by this function
    # propeerties:
    # LogData.meta - Log meta data
    # LogData.log  = List of Log Entries 
    $LogData = [PSCustomObject]@{
        log = [System.Collections.Generic.List[PSCustomObject]]::new();
        meta = $LogMeta
    }

    if (Test-Path $LogFile) {
        #Logfile exists - read it all in and update the meta data       
        $RawFile = Get-Content -Path $LogFile
        $LogData.meta.rawLines=$RawFile.Count
        if ($RawFile[0] -match $tspattern) {
            $LogStart = [DateTime]::Parse($($Matches[0] -replace "_"," "))
            $LogMeta.logStart = $LogStart
        }
        if ($RawFile[-1] -match $tspattern) {
            $LogEnd = [DateTime]::Parse($($Matches[0] -replace "_"," "))
            $LogMeta.logEnd = $LogEnd
        }
        # Validate Time filters against Log start and end times
        if ($StartTime) { 
            if ($StartTime -lt $LogStart -OR $StartTime -gt $LogEnd) {
                Write-Warning "Start Filter incorrect. Setting to Log Start Time"
                $StartTime=$LogStart
            }
            if ($EndTime -lt $LogStart -OR $EndTime -gt $LogEnd) {
                Write-Warning "End Filter incorrect. Setting to Log End Time"
                $EndTime=$LogEnd
            }
            if ($EndTime -lt $StartTime) {
                Write-Error "Filtered End Time must be Greater than Start Time"
                Return
            }
            $LogMeta.filterStart = $StartTime
            $LogMeta.filterEnd = $EndTime
        }

        # Process the log entries        
        #$$LogEntry = $null
        $LineCounter = 1
        foreach ($Line in $RawFile) {
            # Remove any ANSI Color Escapes
            $Line = $Line -replace $colorpattern,''

            if ($Line -match $logpattern) {
                # Full log Entry - Add to $LogData
                # $Matches[1] timestamp
                # $Matches[2] LogTime
                # $Matches[3] Thread
                # $Matches[4] Level (INFO,DEBUG etc)
                # $Matches[5] Class

                #Write-Host "Matched a full Log Entry - line $i" -ForegroundColor Cyan
                try {
                    $TimeStamp = [DateTime]::Parse($($Matches[1] -replace "_"," "))
                } catch {
                    Write-Error "Error Processing UI Log - cannot get a valid TimeStamp - Exiting"
                    return
                }
                
                #is Timestamp within the filter?
                if ($StartTime) {
                    $Capture = ($StartTime -AND ($TimeStamp -ge $StartTime -AND $TimeStamp -le $EndTime))
                } else {
                    $Capture = $True
                }

                # Create Custom Object for a Log Entry
                $LogEntry=[PSCustomObject]@{
                    title = $Line;
                    timestamp = $TimeStamp;
                    lineNumber = $LineCounter;
                    thread = $Matches[3];
                    level = $Matches[4];
                    class = $matches[5];
                    message = [System.Collections.Generic.List[String]]::new()
                }
                #Add the message to to $LogEntry
                $LogEntry.message.Add($Line)
                # Add $LogEntry to $LogData if its within the capture filter
                if ($Capture) {
                    #Write-Host "Adding Line $LineCounter to Log"
                    $LogData.log.Add($LogEntry)
                } else {
                    #Write-Host "Line $LineCounter is outside the Capture Window"
                }
            } else {
                #Continuation line from a Previous log entry - Check if we are capturing?
                if ($Capture) {
                    #Write-Host "Adding a continuation line for Entry $LineCounter ..." -ForegroundColor Blue
                    if ($Clean) {
                        # Optionally cleanup the timestamp at the start of a continuation line
                        $LogData.log[-1].message.Add($($Line -replace $tspattern,''))
                    } else {
                        $LogData.log[-1].message.Add($Line)
                    }
                } else {
                    #Write-Host "Line $LineCounter is outside the Capture Window"
                }
            }
            $LineCounter++
        }
        $LogData.meta.logEntries = $LogData.Log.count
        #Processed all the log entries - filter if Start and End times specified
        #Write a Report before Exiting
        Write-Host "Processing Log File $($LogData.meta.fileName)" -ForegroundColor Green
        Write-Host "Source Log File contains $($LogData.meta.rawLines) Lines" -ForegroundColor Green
        Write-Host "Source Log runs from $($LogData.meta.logStart.ToString("s")) to $($LogData.meta.logEnd.ToString("s"))" -ForegroundColor Green
        Write-Host "Log Entries matching filter = $($LogData.meta.logEntries)" -ForegroundColor Green
        Write-Host "Log Lines matching filter = $($LogData.log.message.count)" -ForegroundColor Green
        if ($Start) {
            Write-Host "Filtered Log runs from $($LogData.meta.filterStart.ToString("s")) to $($LogData.meta.filterEnd.ToString("s"))" -ForegroundColor Green
        }
       
        return $LogData
    } else {
        Write-Warning "Unable to locate Log File $LogFile"
        return $LogData
    }
}

Function Out-UiLog {
    [CmdletBinding()]
    Param (
        [PSCustomObject]$LogData,
        [Switch]$Consolidate,
        [Switch]$AsCsv

    )


    $LogData.Log | Select-Object -Property lineNumber, timestamp, thread, level, @{n="message";e={[String]::Join("`n",$_.message)}} | Out-HtmlPage

}