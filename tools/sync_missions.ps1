param([int]$TimeoutSeconds = 5)
$source = "$PSScriptRoot/../src/controller/*"
$primaryTargets = @(
    "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller_live/",
    "$PSScriptRoot/../missions/Agia_Marina_Vanilla.Stratis/src/controller/"
)
$lockedTarget = "$PSScriptRoot/../missions/Agia_Marina_Semantic.Stratis/src/controller/"

# 1. Sync primary targets (controller_live is never locked by Eden)
$primaryOk = $true
foreach ($target in $primaryTargets) {
    try {
        Copy-Item -Path $source -Destination $target -Force -ErrorAction Stop
    } catch {
        $primaryOk = $false
    }
}

# 2. Attempt legacy target best-effort (may be held open by Eden CfgFunctions)
try {
    Copy-Item -Path $source -Destination $lockedTarget -Force -ErrorAction SilentlyContinue
} catch {}

if ($primaryOk) {
    Write-Output "SYNC_SUCCESS"
} else {
    Write-Output "SYNC_LOCKED"
}
