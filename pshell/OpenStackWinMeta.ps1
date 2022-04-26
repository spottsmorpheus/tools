$metaUri="http://169.254.169.254/openstack/latest"
$latest = Invoke-WebRequest -Uri $metaUri

Write-Host "Oenstack Meta Response" -ForegroundColor Green
Write-Host "$($latest.content)"
Write-Host ""

if ($latest.StatusCode -eq 200) {
    $allContent = $latest.content -split "`n" 
    foreach ($item in $allContent) {
        Write-Host "Content for iten $item" -ForegroundColor Green
        (Invoke-WebRequest -Uri "$metaUri\$item").content
    }
}