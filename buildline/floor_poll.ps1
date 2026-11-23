param(
    [string]$SkipIds = '',
    [string]$TmpPath
)
$url = $env:LOCK_DB_URL
$skipClause = ''
if ($SkipIds -and $SkipIds.Trim() -ne '') {
    $ids = ($SkipIds -split ',') | Where-Object { $_ -match '^\d+$' }
    if ($ids) { $skipClause = ' AND id NOT IN (' + ($ids -join ',') + ')' }
}
$q = "SELECT id, title FROM guardops.board_item WHERE status='OPEN' AND turn='CODE' AND priority=1 AND created_at >= NOW() - INTERVAL '7 days' AND (plan_board_id IS NULL OR plan_board_id NOT IN (SELECT id FROM guardops.board_item WHERE status IN ('DONE','FINISHED','KILLED')))$skipClause ORDER BY created_at DESC LIMIT 1"
try {
    $raw = & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -F '|' -c $q 2>&1
    if ($LASTEXITCODE -eq 0) {
        $line = ($raw | Where-Object { $_ -match '^\d+\|' } | Select-Object -First 1)
        if ($line) {
            [System.IO.File]::WriteAllLines($TmpPath, @($line), (New-Object System.Text.UTF8Encoding $false))
        }
    }
} catch {}
