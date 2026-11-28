param(
    [string]$BoardId,
    [string]$LogPath,
    [string]$RepoPath
)
# Board 12071. One long-lived holding branch called "line". Every job works on it so work
# can never be stranded. Master only moves when the gate is clean.
Set-Location $RepoPath
$br = 'line'

$cur = (git rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()

if ($cur -eq $br) {
    Add-Content -LiteralPath $LogPath -Value 'ALREADY ON line' -Encoding UTF8
    Write-Host 'ALREADY ON line'
} else {
    $lineExists = (git rev-parse --verify --quiet line 2>&1 | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($lineExists)) {
        # "line" does not exist yet - create from CURRENT HEAD, not master, so no work is thrown away
        $out = git branch line 2>&1
        $out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
    }
    # check out without -B and without a start point - never reset the branch
    $out = git checkout line 2>&1
    $out | ForEach-Object { Add-Content -LiteralPath $LogPath -Value $_ -Encoding UTF8; Write-Host $_ }
    # uncommitted changes may prevent checkout - staying put is correct, never exit non-zero for this
}

Add-Content -LiteralPath $LogPath -Value ('ON BRANCH: ' + (git rev-parse --abbrev-ref HEAD)) -Encoding UTF8
