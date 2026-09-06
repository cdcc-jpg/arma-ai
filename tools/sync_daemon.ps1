$source = "$PSScriptRoot/../src/controller/*"
$primaryTargets = @(
    "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller_live/",
    "$PSScriptRoot/../missions/Agia_Marina_Vanilla.Stratis/src/controller/"
)
$lockedTarget = "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller/"

Write-Output "DAEMON_STARTED"
while ($true) {
    $primaryOk = $true
    foreach ($target in $primaryTargets) {
        try {
            Copy-Item -Path $source -Destination $target -Force -ErrorAction Stop
        } catch {
            $primaryOk = $false
        }
    }
    try {
        Copy-Item -Path $source -Destination $lockedTarget -Force -ErrorAction SilentlyContinue
    } catch {}

    if ($primaryOk) {
        Write-Output "DAEMON_SYNC_COMPLETE"
        break
    }
    Start-Sleep -Seconds 1
}
