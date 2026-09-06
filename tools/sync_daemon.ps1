$source = "$PSScriptRoot/../src/controller/*"
$primaryTargets = @(
    "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller_live/",
    "$PSScriptRoot/../missions/Agia_Marina_Vanilla.Stratis/src/controller/",
    "$PSScriptRoot/../missions/Georgetown_Semantic.Tanoa/src/controller_live/",
    "$PSScriptRoot/../missions/Georgetown_Vanilla.Tanoa/src/controller/"
)
$lockedTargets = @(
    "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller/",
    "$PSScriptRoot/../missions/Georgetown_Semantic.Tanoa/src/controller/"
)

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
    foreach ($target in $lockedTargets) {
        try {
            Copy-Item -Path $source -Destination $target -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    if ($primaryOk) {
        Write-Output "DAEMON_SYNC_COMPLETE"
        break
    }
    Start-Sleep -Seconds 1
}
