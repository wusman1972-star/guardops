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
# with it. Every board now starts from master, so a held job stays held and the next job
# cannot stand on top of it.
Set-Location $RepoPath
$br = 'board-' + $BoardId

$base = (git rev-parse --verify --quiet master 2>&1 | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($base)) {
    Add-Content -LiteralPath $LogPath -Value 'NO MASTER to branch from - nothing started' -Encoding UTF8
    Write-Host 'NO MASTER to branch from - nothing started.'
    exit 1
}

$out = git checkout -B $br master 2>&1
$out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $LogPath -Value ('COULD NOT BRANCH ' + $br + ' from master - nothing started') -Encoding UTF8
    exit 1
}
Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + (git rev-parse --abbrev-ref HEAD) + ' cut from master at ' + $base.Substring(0,[Math]::Min(8,$base.Length))) -Encoding UTF8
