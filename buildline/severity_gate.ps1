# Severity gate reader. Prints ONE token on stdout:
#   a number     - the HIGHEST count of critical/major findings across every
#                  FINISHED review of this board
#   0            - no review of this board ever finished, and at least one was
#                  skipped because there was no reviewable change
#   NOVERDICT    - no verdict file for this board
#   NOTCOMPLETE  - verdict files exist but no review in any of them finished
# Reads only. Never throws: any fault prints NOTCOMPLETE so the line shouts instead of dying.
#
# 23 Nov: rewritten after it reported 0 on board 11733, a real review carrying nine major
# findings. The old version searched the whole file for the words "reviewer skipped" and
# CodeRabbit had used those words inside one of its own comments, so prose was read as a
# marker. Nothing is matched against free text now: the skip marker must be its own line,
# and findings are counted by parsing each JSON line, not by scanning the file.
#
# 24 Nov, board 11883: it read only the NEWEST verdict file for the board. On board 11878 a
# real review at 10:27 completed with two MAJOR findings; a second run at 10:34 had nothing
# left to look at and wrote "no reviewable change, reviewer skipped". That skip was newer,
# so the gate read it, reported 0, and both Majors merged into master. Now EVERY verdict
# file for the board is read and the HIGHEST finished count wins - a later empty review can
# no longer wipe out a real finding.
# DECLARED TRADEOFF: once a Major is counted for a board, that board cannot merge even after
# the fault is fixed, because a re-review carries the same board number. The fix takes a NEW
# board - which is the one-job-one-board rule anyway.
$ErrorActionPreference = 'Stop'
try {
    $dir = Join-Path $env:GOPS_REPO 'tools\verdicts'
    $board = $env:BOARD_ID
    if ([string]::IsNullOrWhiteSpace($board)) { Write-Output 'NOTCOMPLETE'; exit 0 }

    $files = @(Get-ChildItem -Path $dir -Filter ("cr_verdict_" + $board + "_*") -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime)
    if ($files.Count -eq 0) { Write-Output 'NOVERDICT'; exit 0 }

    $anyFinished = $false
    $worst       = 0
    $anySkip     = $false

    foreach ($file in $files) {
        $lines = Get-Content -LiteralPath $file.FullName
        $finished = $false
        $count = 0
        foreach ($line in $lines) {
            $t = $line.Trim()
            if (-not $t.StartsWith('{')) { continue }
            try { $o = $t | ConvertFrom-Json } catch { continue }
            if ($o.type -eq 'complete' -and $o.status -eq 'review_completed') { $finished = $true }
            if ($o.type -eq 'finding' -and ($o.severity -eq 'critical' -or $o.severity -eq 'major')) { $count++ }
        }
        if ($finished) {
            $anyFinished = $true
            if ($count -gt $worst) { $worst = $count }
        } else {
            # A skip is only a skip when the producer wrote it as its own marker line.
            foreach ($line in $lines) {
                if ($line -match '^\s*=====.*no reviewable change.*=====\s*$') { $anySkip = $true }
            }
        }
    }

    if ($anyFinished) { Write-Output "$worst"; exit 0 }
    if ($anySkip)     { Write-Output 'SKIPPED'; exit 0 }

    Write-Output 'NOTCOMPLETE'
    exit 0
} catch {
    Write-Output 'NOTCOMPLETE'
    exit 0
}
