# board 12015: hard size limit for the build line.
# Called from cr_review.bat before the reviewer runs.
# Exits 0 (pass) or 1 (stopped: branch pushed, hold board filed).
param(
    [string]$VerdictFile,
    [string]$BaseSha,
    [string]$BoardId
)

$repoRoot  = $env:GOPS_REPO
$limitFile = Join-Path $repoRoot 'tools\max_job_lines.txt'

$limit = 120
if (Test-Path $limitFile) {
    $raw = ''
    try { $raw = (Get-Content -LiteralPath $limitFile -ErrorAction Stop | Select-Object -First 1).Trim() } catch {}
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed) -and $parsed -gt 0) { $limit = $parsed }
}

$stateFileList = @(
    'tools/cr_last.txt',
    'tools/cr_done.flag',
    'tools/cr_running.flag',
    'tools/cr_reviewed_head.txt'
)
function Skip-StateFile([string]$f) {
    if ($stateFileList -contains $f.ToLower()) { return $true }
    if ($f -imatch '^tools/verdicts/')          { return $true }
    if ($f -imatch '^supabase/schemas/')         { return $true }
    return $false
}

$totalLines   = 0
$touchedFiles = @()

if (-not $BaseSha) {
    Add-Content -LiteralPath $VerdictFile "===== SIZE GATE FAIL: BaseSha is empty - cannot measure the diff ====="
    exit 1
}
$resolvedSha = & git rev-parse --verify "${BaseSha}^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $VerdictFile "===== SIZE GATE FAIL: BaseSha '$BaseSha' does not resolve to a commit ====="
    exit 1
}
$numstat = & git diff --numstat "${BaseSha}...HEAD" 2>$null
if ($LASTEXITCODE -ne 0) {
    Add-Content -LiteralPath $VerdictFile "===== SIZE GATE FAIL: git diff failed (exit $LASTEXITCODE) - cannot measure ====="
    exit 1
}
foreach ($line in $numstat) {
    if ($line -match '^(\d+)\s+(\d+)\s+(.+)$') {
        $file = $Matches[3].Trim()
        if (Skip-StateFile $file) { continue }
        $totalLines   += [int]$Matches[1] + [int]$Matches[2]
        $touchedFiles += $file
    }
}

Add-Content -LiteralPath $VerdictFile "===== SIZE GATE: $totalLines lines changed (limit $limit) ====="

if ($totalLines -le $limit) {
    exit 0
}

# STOP: job over the limit
$fileCount = $touchedFiles.Count
$fileList  = ($touchedFiles | Select-Object -First 30) -join "`n  "
$stopMsg   = "SIZE GATE STOP: $totalLines lines changed, limit is $limit. Files touched (${fileCount}):`n  $fileList"
Add-Content -LiteralPath $VerdictFile "===== $stopMsg ====="

# Push the branch so the work is not lost - never push master
$branch = (& git rev-parse --abbrev-ref HEAD 2>$null) -join ''
if ($branch -and $branch -ne 'HEAD' -and $branch -ne 'master') {
    $pushOut = & git push --set-upstream origin $branch 2>&1
    foreach ($ln in $pushOut) {
        Add-Content -LiteralPath $VerdictFile "git push: $ln"
    }
} elseif ($branch -eq 'master') {
    Add-Content -LiteralPath $VerdictFile "===== SIZE HOLD PUSH REFUSED: on master, pushing nothing ====="
    Write-Host "SIZE HOLD: on master - push refused, nothing sent to remote"
}

# File hold board via psql (REST API anon key does not reach RPC on this floor).
# Floor is in BUILD mode so board_add runs without take_look.
$psql = 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe'
$url  = $env:LOCK_DB_URL
if ($url -and (Test-Path $psql)) {
    $title      = "SIZE HOLD: board $BoardId changed $totalLines lines (limit $limit)"
    $detail     = "Board $BoardId stopped by the size gate.`n`n$totalLines lines changed; limit is $limit.`n`nFiles touched (${fileCount}):`n  $fileList`n`nReduce the scope and open a new board to carry the corrected work."
    $titleSql   = $title  -replace "'", "''"
    $detailSql  = ($detail -replace "'", "''") -replace "`n", "' || chr(10) || '"
    $q = "SELECT guardops.board_add(p_title := '$titleSql', p_turn := 'OPUS', p_actor := 'CODE'," +
         " p_priority := 1, p_detail := '$detailSql', p_ref := $BoardId, p_plan_id := 3590);"
    $tmpSql = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "size_hold_${BoardId}.sql")
    try {
        $q | Set-Content -LiteralPath $tmpSql -Encoding UTF8
        $raw = & $psql $url -t -A -f $tmpSql 2>&1
        Remove-Item $tmpSql -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0) {
            $newId = ($raw -join '').Trim()
            Add-Content -LiteralPath $VerdictFile "===== SIZE HOLD BOARD filed as board $newId ====="
            Write-Host "SIZE HOLD filed as board $newId"
        } else {
            Add-Content -LiteralPath $VerdictFile "===== SIZE HOLD BOARD psql failed: $($raw -join ' ') ====="
            Write-Host "SIZE HOLD board filing failed (psql): $($raw -join ' ')"
        }
    } catch {
        Remove-Item $tmpSql -ErrorAction SilentlyContinue
        Add-Content -LiteralPath $VerdictFile "===== SIZE HOLD BOARD psql error: $_ ====="
        Write-Host "SIZE HOLD board filing error: $_"
    }
} else {
    Add-Content -LiteralPath $VerdictFile "===== SIZE HOLD BOARD not filed: psql or LOCK_DB_URL not available ====="
}

exit 1
