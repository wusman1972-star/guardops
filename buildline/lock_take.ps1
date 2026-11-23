param(
    [string]$BoardId,
    [string]$LogPath
)
$url = $env:LOCK_DB_URL
try {
    $q = "SELECT public.gops_take_driver_lock('CODE1',$BoardId)"
    $raw = & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c $q 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'psql error: ' + ($raw -join ' ') }
    $r = ($raw -join '').Trim() | ConvertFrom-Json
    if ($r.ok -eq $false) {
        Add-Content -LiteralPath $LogPath -Value ('===== LOCK REFUSED board ' + $BoardId + ' ' + (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') + ' - held by ' + $r.holder + ' since ' + $r.since + ' =====') -Encoding UTF8
        exit 1
    }
} catch {
    Add-Content -LiteralPath $LogPath -Value ('===== LOCK TRANSPORT ERROR board ' + $BoardId + ' ' + (Get-Date -Format 'MM/dd/yyyy HH:mm:ss') + ' - could not reach the lock: ' + $_ + ' =====') -Encoding UTF8
    exit 1
}
