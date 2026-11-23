# Severity gate reader. Prints ONE token on stdout:
#   a number     - count of critical/major findings in the newest verdict for this board
#   0            - the reviewer was skipped because there was no reviewable change
#   NOVERDICT    - no verdict file for this board
#   NOTCOMPLETE  - a verdict exists but no review in it finished
# Reads only. Never throws: any fault prints NOTCOMPLETE so the line shouts instead of dying.
#
# 23 Nov: rewritten after it reported 0 on board 11733, a real review carrying nine major
# findings. The old version searched the whole file for the words "reviewer skipped" and
# CodeRabbit had used those words inside one of its own comments, so prose was read as a
# marker. Nothing is matched against free text now: the skip marker must be its own line,
# and findings are counted by parsing each JSON line, not by scanning the file.
$ErrorActionPreference = 'Stop'
try {
    $dir = Join-Path $env:GOPS_REPO 'tools\verdicts'
    $board = $env:BOARD_ID
    if ([string]::IsNullOrWhiteSpace($board)) { Write-Output 'NOTCOMPLETE'; exit 0 }

    $file = Get-ChildItem -Path $dir -Filter ("cr_verdict_" + $board + "_*") -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $file) { Write-Output 'NOVERDICT'; exit 0 }

    $lines = Get-Content -LiteralPath $file.FullName

    # Did any review in this file actually finish? Only a parsed complete record counts.
    $finished = $false
    $count = 0
    foreach ($line in $lines) {
        $t = $line.Trim()
        if (-not $t.StartsWith('{')) { continue }
        try { $o = $t | ConvertFrom-Json } catch { continue }
        if ($o.type -eq 'complete' -and $o.status -eq 'review_completed') { $finished = $true }
        if ($o.type -eq 'finding' -and ($o.severity -eq 'critical' -or $o.severity -eq 'major')) { $count++ }
    }
    if ($finished) { Write-Output "$count"; exit 0 }

    # No finished review. A skip is only a skip when the producer wrote it as its own marker line.
    foreach ($line in $lines) {
        if ($line -match '^\s*=====.*no reviewable change.*=====\s*$') { Write-Output '0'; exit 0 }
    }

    Write-Output 'NOTCOMPLETE'
    exit 0
} catch {
    Write-Output 'NOTCOMPLETE'
    exit 0
}
