param(
    [string]$BoardId,
    [string]$LogPath,
    [string]$RepoPath
)
Set-Location $RepoPath
$codeSource = Join-Path (Split-Path $RepoPath -Parent) 'Code.bat'
$codeDest   = Join-Path $RepoPath 'buildline\Code.bat'
if (Test-Path $codeSource) {
    Copy-Item -LiteralPath $codeSource -Destination $codeDest -Force
} else {
    Add-Content -LiteralPath $LogPath -Value "PRE-REVIEW COMMIT: Code.bat not found at $codeSource, skipping mirror" -Encoding UTF8
}
git add migrations/ tools/ buildline/ .gitignore 2>&1 | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8 }
$staged = (git diff --cached --name-only)
if ($staged) {
    $msg = 'board ' + $BoardId + ' job commit'
    $out = git commit -m $msg 2>&1
    $out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $summary = 'PRE-REVIEW COMMIT OK: ' + ($staged -join ', ')
    Add-Content -LiteralPath $LogPath -Value $summary -Encoding UTF8
    Write-Host $summary
} else {
    Add-Content -LiteralPath $LogPath -Value 'PRE-REVIEW COMMIT: nothing to commit' -Encoding UTF8
    Write-Host 'PRE-REVIEW COMMIT: nothing to commit'
}
