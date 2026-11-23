param(
    [string]$SkipIds = '',
    [string]$TmpPath
)
$url = $env:LOCK_DB_URL
$q = "SELECT id, title FROM guardops.take_next_job('CODE', 'CODE')"
try {
    $raw = & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -F '|' -c $q 2>&1
    if ($LASTEXITCODE -eq 0) {
        $line = ($raw | Where-Object { $_ -match '^\d+\|' } | Select-Object -First 1)
        if ($line) {
            [System.IO.File]::WriteAllLines($TmpPath, @($line), (New-Object System.Text.UTF8Encoding $false))
        }
    }
} catch {}
