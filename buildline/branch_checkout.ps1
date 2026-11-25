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
# a new one from master. Nothing bad rides onto master by doing this: the merge gate still runs
# on every job, and the reviewer now reads the committed diff against master, so what it judges
# is the whole accumulated change before any of it lands.
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
