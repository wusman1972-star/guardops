# Severity gate reader. Prints one token on stdout:
#   a number       - count of critical/major findings in the newest verdict for this board
#   0              - review was skipped because there was no reviewable change
#   NOVERDICT      - no verdict file for this board
#   NOTCOMPLETE    - verdict exists but the review was killed before it finished
# Reads only. Never throws: any fault prints NOTCOMPLETE so the line shouts instead of dying.
$ErrorActionPreference = 'Stop'
try {
    $dir = Join-Path $env:GOPS_REPO 'tools\verdicts'
    $file = Get-ChildItem -Path $dir -Filter ("cr_verdict_" + $env:BOARD_ID + "_*") -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $file) { Write-Output 'NOVERDICT'; exit 0 }
    $text = Get-Content -Raw -LiteralPath $file.FullName
    if ($text -match 'reviewer skipped')      { Write-Output '0'; exit 0 }
    if ($text -notmatch 'review_completed')   { Write-Output 'NOTCOMPLETE'; exit 0 }
    $n = ([regex]::Matches($text, '"severity"\s*:\s*"(critical|major)"')).Count
    Write-Output "$n"
    exit 0
} catch {
    Write-Output 'NOTCOMPLETE'
    exit 0
}
