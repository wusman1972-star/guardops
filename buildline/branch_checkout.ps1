param(
    [string]$BoardId,
    [string]$LogPath,
    [string]$RepoPath
)
Set-Location $RepoPath
$br = 'board-' + $BoardId
$out = git checkout -B $br 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + (git rev-parse --abbrev-ref HEAD)) -Encoding UTF8
