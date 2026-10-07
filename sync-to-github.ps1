# Commits any changes in this project and pushes them to GitHub (origin/main).
# Run by a Windows scheduled task every day at 4:30 PM Central; can also be run by hand.

$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

$log = Join-Path $PSScriptRoot "sync.log"
function Write-Log($message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $message" | Add-Content -Path $log
}

Write-Log "Sync started"

git add -A 2>&1 | Out-Null

# Commit only if something changed.
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitOutput = git commit -m "Daily sync $stamp" 2>&1
    Write-Log "Committed: $($commitOutput | Select-Object -First 1)"
} else {
    Write-Log "No new changes to commit"
}

# Push even when there was nothing new to commit, in case an earlier push failed.
$pushOutput = git push -u origin main 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Log "Push OK"
} else {
    Write-Log "Push FAILED: $($pushOutput -join ' ')"
    exit 1
}
