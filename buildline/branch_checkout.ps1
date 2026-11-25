param(
    [string]$BoardId,
    [string]$LogPath,
    [string]$RepoPath
)
# 24 Nov, board 11883. This used to be "git checkout -B $br" with no starting point, so the
# branch was cut from WHEREVER THE LAST JOB LEFT HEAD - not from master, despite the comment
# in Code.bat saying "off master". That defeated the merge hold completely: board 11876 was
# held with six Major findings and master was correctly left alone, but the next job branched
# off that held commit, passed its own gate, merged - and carried all six Majors onto master
# with it.
#
# 25 Nov 2026, Waqar's order. Cutting every job from master fixed that but opened the opposite
# hole: when a merge is held, master does not move, so the NEXT job cut from master and did not
# have the held work. A held FIX was therefore thrown away and the next job started again from
# the old broken code. That is how 93 branches piled up with today's fixes split across two of
# them, neither holding the other's work, and nothing ever reaching master.
#
# A held job is not finished. So the next job CONTINUES ON THE HELD BRANCH instead of starting
# a new one from master.
#
# What actually covers the carried-on commits, stated exactly, because the earlier wording here
# claimed a guarantee it does not have: cr_review.bat sets its base to
# `git merge-base origin/master HEAD` (board 12007), so the review normally reads every commit
# the merge would add to master, carried-on ones included - verified on boards 12044 and 12048,
# where the base was origin/master 12dbcee and the diff covered all ten commits. BUT that is not
# a guarantee: if merge-base fails, cr_review.bat falls back to tools\cr_reviewed_head.txt and
# then to HEAD~1, and either fallback would review only the newest commit while the merge still
# carries the rest. The severity gate reads only the current board's verdict files, so on that
# fallback path a held Major could reach master. The fallback is the hole to close, not the
# carry-on itself. Do not restore the old comment claiming master is always the base.
Set-Location $RepoPath
$br = 'board-' + $BoardId

$base = (git rev-parse --verify --quiet master 2>&1 | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($base)) {
    Add-Content -LiteralPath $LogPath -Value 'NO MASTER to branch from - nothing started' -Encoding UTF8
    Write-Host 'NO MASTER to branch from - nothing started.'
    exit 1
}

# Is there a held branch to carry on from? Code.bat writes tools\held_branch.txt when it holds
# a merge and deletes it when one lands. Only honour it if the branch still exists AND still
# has work that master does not have - otherwise it is stale and master is the right base.
$heldFile = Join-Path $RepoPath 'tools\held_branch.txt'
$held = ''
if (Test-Path -LiteralPath $heldFile) {
    $held = (Get-Content -LiteralPath $heldFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($null -eq $held) { $held = '' }
    $held = $held.Trim()
}
# If the hold names THIS board's own branch, never run checkout -B against master: that resets
# the branch and deletes the held commits from its tip. Check the branch out as it stands.
if ($held -ne '' -and $held -eq $br) {
    git rev-parse --verify --quiet ('refs/heads/' + $br) *> $null
    if ($LASTEXITCODE -eq 0) {
        $out = git checkout $br 2>&1
        $out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Add-Content -LiteralPath $LogPath -Value ('COULD NOT CHECK OUT THE HELD BRANCH ' + $br + ' - nothing started') -Encoding UTF8
            exit 1
        }
        $tip = (git rev-parse HEAD 2>&1 | Out-String).Trim()
        Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + $br + ' RESUMED its own held tip at ' + $tip.Substring(0,[Math]::Min(8,$tip.Length)) + ' - not reset to master, the held work is kept') -Encoding UTF8
        exit 0
    }
}

$carryOn = ''
if ($held -ne '' -and $held -ne $br) {
    git rev-parse --verify --quiet ('refs/heads/' + $held) *> $null
    if ($LASTEXITCODE -eq 0) {
        $ahead = (git rev-list --count ('master..' + $held) 2>&1 | Out-String).Trim()
        if ($ahead -match '^\d+$' -and [int]$ahead -gt 0) {
            $carryOn = $held
        } else {
            Add-Content -LiteralPath $LogPath -Value ('HELD BRANCH ' + $held + ' has nothing master lacks - ignoring it and cutting from master') -Encoding UTF8
        }
    } else {
        Add-Content -LiteralPath $LogPath -Value ('HELD BRANCH ' + $held + ' no longer exists - cutting from master') -Encoding UTF8
    }
}

if ($carryOn -ne '') {
    $out = git checkout -B $br $carryOn 2>&1
    $out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Add-Content -LiteralPath $LogPath -Value ('COULD NOT BRANCH ' + $br + ' from held branch ' + $carryOn + ' - nothing started') -Encoding UTF8
        exit 1
    }
    $tip = (git rev-parse $carryOn 2>&1 | Out-String).Trim()
    Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + (git rev-parse --abbrev-ref HEAD) + ' CARRIED ON from held branch ' + $carryOn + ' at ' + $tip.Substring(0,[Math]::Min(8,$tip.Length)) + ' - the held work is kept, not thrown away') -Encoding UTF8
    exit 0
}

$out = git checkout -B $br master 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('COULD NOT BRANCH ' + $br + ' from master - nothing started') -Encoding UTF8
    exit 1
}
Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + (git rev-parse --abbrev-ref HEAD) + ' cut from master at ' + $base.Substring(0,[Math]::Min(8,$base.Length))) -Encoding UTF8
