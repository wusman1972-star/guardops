# Checks whether the latest finished verdict for this board covered the full branch.
# "Full" means the verdict's base commit equals origin/master — every commit on the
# branch was under review, not just the newest job's delta.
#
# Outputs one token:
#   FULL     - base SHA in verdict matches origin/master; safe to clear the hold
#   PARTIAL  - base SHA known but does not match origin/master; held commits were not seen
#   UNKNOWN  - base SHA cannot be read, or git cannot resolve origin/master; hold stays
#
# Hole 856: a later job whose own review is clean must not lift a hold from commits
# its review never examined. Called by Code.bat only when a hold file is already active.
$ErrorActionPreference = 'Stop'
try {
    $dir   = Join-Path $env:GOPS_REPO 'tools\verdicts'
    $board = $env:BOARD_ID
    if ([string]::IsNullOrWhiteSpace($board)) { Write-Output 'UNKNOWN'; exit 0 }

    $masterSha = (& git -C $env:GOPS_REPO rev-parse origin/master 2>&1 | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($masterSha) -or $masterSha -notmatch '^[0-9a-f]{40}$') {
        Write-Output 'UNKNOWN'; exit 0
    }

    $files = @(Get-ChildItem -Path $dir -Filter ("cr_verdict_" + $board + "_*") -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending)

    foreach ($file in $files) {
        $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { continue }

        $finished = $false
        $baseSha  = $null

        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -match '=====\s+base\s+\S+\s+\(([0-9a-f]{40})\)') {
                $baseSha = $Matches[1]
                continue
            }
            if (-not $t.StartsWith('{')) { continue }
            try { $o = $t | ConvertFrom-Json } catch { continue }
            if ($o.type -eq 'complete' -and $o.status -eq 'review_completed') { $finished = $true }
        }

        if ($finished) {
            if (-not $baseSha)         { Write-Output 'UNKNOWN';  exit 0 }
            if ($baseSha -eq $masterSha) { Write-Output 'FULL' }
            else                         { Write-Output 'PARTIAL' }
            exit 0
        }
    }

    Write-Output 'UNKNOWN'
    exit 0
} catch {
    Write-Output 'UNKNOWN'
    exit 0
}
