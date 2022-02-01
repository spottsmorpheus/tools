# find the path to the desktop folder:
$documents = [Environment]::GetFolderPath('MyDocuments')
$savedFiles = join-path -Path $documents -ChildPath "Watcher"

# specify the path to the folder you want to monitor:
$Path = "c:\windows\temp"
# specify which files you want to monitor
$FileFilter = '*'  

# specify whether you want to monitor subfolders as well:
$IncludeSubfolders = $true

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite 

# specify the type of changes you want to monitor:
#$ChangeTypes = [System.IO.WatcherChangeTypes]::Changed
$ChangeTypes = [System.IO.WatcherChangeTypes]::Created

# specify the maximum time (in milliseconds) you want to wait for changes:
$Timeout = 1000

# define a function that gets called for every change:
function Invoke-SomeAction
{
  param
  (
    [Parameter(Mandatory)]
    [System.IO.WaitForChangedResult]
    $ChangeInformation,
    [string]$watchPath,
    [string]$savePath
  )
  
  Write-Warning "Filesystem Event: $($ChangeInformation.ChangeType): $($ChangeInformation.Name)"
  # Snatch a copy of the file
  $src = join-path -path $watchPath -childpath $($ChangeInformation.Name)
  $trg = join-path -path $savePath -childpath $($ChangeInformation.Name)
  new-item -force $trg -ErrorAction SilentlyContinue
  try {
      copy-item -recurse -force -path $src -destination $trg -ErrorAction SilentlyContinue
      Write-Host "Captured File $($trg)" -ForegroundColor Green
  }
  catch {
     Write-Warning "Clearing Temp item $trg" 
     Remove-Item -Force -ErrorAction SilentlyContinue -Path $trg
  }

}

# use a try...finally construct to release the
# filesystemwatcher once the loop is aborted
# by pressing CTRL+C

try
{
  Write-Warning "FileSystemWatcher is monitoring $Path"
  
  # create a filesystemwatcher object
  $watcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList $Path, $FileFilter -Property @{
    IncludeSubdirectories = $IncludeSubfolders
    NotifyFilter = $AttributeFilter
  }

  # start monitoring manually in a loop:
  do
  {
    # wait for changes for the specified timeout
    # IMPORTANT: while the watcher is active, PowerShell cannot be stopped
    # so it is recommended to use a timeout of 1000ms and repeat the
    # monitoring in a loop. This way, you have the chance to abort the
    # script every second.
    $result = $watcher.WaitForChanged($ChangeTypes, $Timeout)
    # if there was a timeout, continue monitoring:
    if ($result.TimedOut) { continue }
    
    Invoke-SomeAction -Change $result -WatchPath $path -savePath $savedFiles
    # the loop runs forever until you hit CTRL+C    
  } while ($true)
}
finally
{
  # release the watcher and free its memory:
  $watcher.Dispose()
  Write-Warning 'FileSystemWatcher removed.'
}