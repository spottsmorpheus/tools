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

    # Regex Patterns

    #Log Pattern for full morpheus-ui Logs
    #   $Matches[1]=Timestamp; $Matches[2]=LogTime; $Matches[3]=Thread; $Matches[4]=level; $Matches[5]=Class $Matches[6]=message
    $logpatternFull = "^([0-9-]+_[0-9:]+\.[0-9]*).*\[([0-9-:, ]*)\]\s+\[([a-zA-Z0-9-\.]*)\]\s+([A-Z]*)\s+([a-zA-Z0-9\.]*)[\s-]*(.*)$"

    #Log Pattern for Exported UI Logs
    #   $Matches[1]=Timestamp; $Matches[2]=level; $Matches[3]=Thread; $Matches[4]=message
    $logpatternUi = "^\[([0-9-:T]*)Z\]\s+([A-Z]*)\s+\[([a-zA-Z0-9-\.]*)\]\s*(.*)$"

    # Timestamp in Full logs YYYY-MM-DD_hh:mm:ss.uuuuu - also used as a prefix on a continuation line in full UI logs
    $tspatternFull="^([0-9-]+_[0-9:]+\.[0-9]*)"

    # Timestamp Pattern in Exported UI
    $tspatternUi = "^\[([0-9-:T]*)Z\]"

    $matchAny = "^.*$"

    #ANSI Escape colour sequences
    $colorpattern = "\u001B[\[0-9;]*[a-zA-Z]"

    # Test the first 5 lines of the file to discover the format

    if (Test-Path $LogFile) {
        $RawFile = Get-Content -Path $LogFile
        #Try and discover format try first 5lines
        $CheckingFormat = $true
        $i=0
        While ($CheckingFormat -and $i -lt 5) {
            $Line = $RawFile[$i] -replace $colorpattern,''
            if ($Line -match $logpatternFull) {
                Write-Host "Determined format as Full UI Logs" -ForegroundColor Green
                $CheckingFormat=$false
                $LogPattern = $logpatternFull
                $TimeStampPattern = $tspatternFull
                $ContPattern = $tspatternFull
                $LogFormat = "Full-Ui"
            } elseif ($Line -match $logpatternUi) {
                Write-Host "Determined format as Exported Logs or Logs from UI or API" -ForegroundColor Green
                $CheckingFormat=$false
                $LogPattern = $logpatternUi
                $TimeStampPattern = $tspatternUi
                $ContPattern = $matchAny # Match Anything
                $LogFormat = "Exported-Ui"
            } else {
                Write-Warning "Unknown Log File format Line $($i)"
                $i++
            }
        }
        if ($CheckingFormat) {
            Write-Error "Unable to determine valid Log format after 5 lines - quitting"
            return $null
        }
    } else {
        Write-Error "Cannot Open file $Logfile"
        return $null
    }

    #At this point file exists and format has been determined

    # If Parameters exist fot Filtering validate these for the correct format

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
    
    #Logfile loaded into $RawFile try and determine the start and end timestamps      

    if ($RawFile[0] -match $TimeStampPattern) {
        if ($LogFormat -eq "Full-UI") {
            $LogStart = [DateTime]::Parse($($Matches[1] -replace "_"," "))
        } else {
            $LogStart = [DateTime]::Parse($Matches[1])
        }
        write-host "Log Start $($matches[1])"
    } else {
        Write-Warning "Unable to Determing the Starting Timestamp from First Line of Log"
        $LogStart = $null
    }
    if ($RawFile[-1] -match $TimeStampPattern) {
        if ($LogFormat -eq "Full-UI") {
            $LogEnd = [DateTime]::Parse($($Matches[1] -replace "_"," "))
        } else {
            $LogEnd = [DateTime]::Parse($Matches[1])
        }
        write-host "Log End $($matches[1])"
    } else {
        Write-Warning "Unable to Determing the Ending Timestamp from Last Line of Log"
        $LogEnd = $null
    }

    #Create the Objects which will return the processed Log Data

    # Log Metadata Object
    $LogMeta = [PSCustomObject]@{
        fileName = $LogFile;
        rawLines = $RawFile.count;
        logEntries = 0;
        format = $LogFormat;
        logStart = $LogStart;
        logEnd = $LogEnd;
        filterStart=$null;
        filterEnd=$null
    }
    # Main Object - Returned by this function
    # properties:
    # LogData.meta - Log meta data
    # LogData.log  = List of Log Entries 
    $LogData = [PSCustomObject]@{
        log = [System.Collections.Generic.List[PSCustomObject]]::new();
        meta = $LogMeta
    }

    # Validate Time filters against Log start and end times only of Start and End times can be determined
    if ($StartTime -And ($LogStart -And $LogEnd)) { 
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

    $LineCounter = 1
    foreach ($Line in $RawFile) {
        # Remove any ANSI Color Escapes
        $Line = $Line -replace $colorpattern,''
        # Try a Match on $LogPattern 
        if ($Line -match $LogPattern) {
            # Line matches a Log entry pattern - determine the format and extract the data
            if ($LogFormat -eq "Full-UI") {
                # Full UI Format
                try {
                    $TimeStamp = [DateTime]::Parse($($Matches[1] -replace "_"," "))
                } catch {
                    Write-Error "Error Processing UI Log - cannot get a valid TimeStamp - Exiting"
                    return
                }
                # Create Custom Object for a Full-UI Log Entry
                $LogEntry=[PSCustomObject]@{
                    title = $Line;
                    timestamp = $TimeStamp;
                    lineNumber = $LineCounter;
                    thread = $Matches[3];
                    level = $Matches[4];
                    class = $matches[5];
                    message = [System.Collections.Generic.List[String]]::new()
                }
                $LogEntry.message.Add($Matches[6])
            } else {
                # Exported UI Format
                try {
                    $TimeStamp = [DateTime]::Parse($Matches[1])
                } catch {
                    Write-Error "Error Processing Exported UI Log - cannot get a valid TimeStamp - Exiting"
                    return
                }
                # Create Custom Object for a Exported-UI Log Entry
                $LogEntry=[PSCustomObject]@{
                    title = $Line;
                    timestamp = $TimeStamp;
                    lineNumber = $LineCounter;
                    thread = $Matches[3];
                    level = $Matches[2];
                    class = "";
                    message = [System.Collections.Generic.List[String]]::new()
                }
                $LogEntry.message.Add($Matches[4])
            }
            #is Timestamp within the filter?
            if ($StartTime) {
                $Capture = ($StartTime -AND ($TimeStamp -ge $StartTime -AND $TimeStamp -le $EndTime))
            } else {
                $Capture = $True
            }
            # Add $LogEntry to $LogData if its within the capture filter
            if ($Capture) {
                #Write-Host "Adding Line $LineCounter to Log"
                $LogData.log.Add($LogEntry)
            } else {
                #Write-Host "Line $LineCounter is outside the Capture Window"
            }
        } elseif ($Line -match $ContPattern) {
            #Continuation line from a Previous log entry - Check if we are capturing?
            if ($LogFormat -eq "Full-UI") {
                if ($Capture) {
                    #Write-Host "Adding a continuation line for Entry $LineCounter ..." -ForegroundColor Blue
                    if ($Clean) {
                        # Optionally cleanup the timestamp at the start of a continuation line
                        $LogData.log[-1].message.Add($($Line -replace $TimeStampPattern,''))
                    } else {
                        $LogData.log[-1].message.Add($Line)
                    }
                } else {
                    #Write-Host "Line $LineCounter is outside the Capture Window"
                }
            } else {
                if ($Capture) {
                    $LogData.log[-1].message.Add($Line)
                } else {
                    #Write-Host "Line $LineCounter is outside the Capture Window"
                }
            }
        } else {
                #Got a badly formed log entry
                Write-Warning "Skipping malformed log Line $LineCounter"
        }

        #Linecounter refers to the original file line
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

}


Function Out-UiLog {
    [CmdletBinding()]
    Param (
        [Object[]]$LogData,
        [Switch]$Consolidate,
        [Switch]$AsCsv,
        [String]$Filter

    )
    
    $LogData | 
    Select-Object -Property lineNumber, timestamp, thread, level, class, @{n="message";e={[String]::Join("`n",$_.message)}} | Out-HtmlPage

    
 
}