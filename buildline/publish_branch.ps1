param(
    [string]$LogPath,
    [string]$BoardId,
    [string]$RepoPath,
    [switch]$BranchOnly
)
Set-Location $RepoPath
$br = 'board-' + $BoardId

# 24 Nov, board 11883. This used to be "git push origin HEAD". HEAD is whatever happens to
# be checked out, so if an earlier run left master checked out, a retry pushed MASTER even
# while the merge was being held - which made the hold worth nothing. Now the board branch
# is named explicitly, and the run stops if that branch is not the one checked out rather
# than guessing or switching branches on its own.
$cur = (git rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
if ($cur -ne $br) {
    Add-Content -LiteralPath $LogPath -Value ('WRONG BRANCH: expected ' + $br + ' but ' + $cur + ' is checked out - nothing pushed, nothing merged') -Encoding UTF8
    Write-Host ('WRONG BRANCH: expected ' + $br + ' but ' + $cur + ' is checked out. Nothing was pushed.')
    return
}

$out = git push origin $br 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('BRANCH PUSH FAILED for ' + $br + ' - branch not landed') -Encoding UTF8
    return
}

# Hole 841 / his order 24 Nov: a Critical or Major finding holds the MERGE, never the work.
# The branch is already on GitHub above, so nothing is lost and nobody is stopped. Only
# master is protected, because master is what the install is built from.
if ($BranchOnly) {
    Add-Content -LiteralPath $LogPath -Value ('MERGE HELD: ' + $br + ' is pushed as a branch but NOT merged into master - the review has an open Critical or Major finding. Fix it, then merge.') -Encoding UTF8
    Write-Host ('MERGE HELD: ' + $br + ' is on GitHub as a branch. It is NOT on master.')
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
