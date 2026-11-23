param(
    [string]$LogPath,
    [string]$BoardId,
    [string]$RepoPath
)
Set-Location $RepoPath
$br = 'board-' + $BoardId
$out = git push origin HEAD 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('BRANCH PUSH FAILED for ' + $br + ' - branch not landed') -Encoding UTF8
    return
}
$out = git checkout master 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('CHECKOUT MASTER FAILED for ' + $br + ' - branch not landed') -Encoding UTF8
    return
}
$out = git merge --ff-only $br 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('MERGE TO MASTER FAILED for ' + $br + ' - branch left unmerged') -Encoding UTF8
    return
}
$out = git push origin master 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('MASTER PUSH FAILED for ' + $br + ' - merged locally not pushed') -Encoding UTF8
    return
}
Add-Content -LiteralPath $LogPath -Value ('MERGED AND PUSHED: ' + $br + ' -> master') -Encoding UTF8
