param(
    [string]$LogPath,
    [string]$RepoPath
)
Set-Location $RepoPath
$out = git fetch origin master:refs/remotes/origin-real-master 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
