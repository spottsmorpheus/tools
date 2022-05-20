write-host "<%=morpheus.applianceUrl%>"
$MyInvocation
$Host
[System.Environment]::GetEnvironmentVariables()
write-host "PID"
pstree -s $PID