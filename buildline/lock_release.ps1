$url = $env:LOCK_DB_URL
try {
    & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c "SELECT public.gops_release_driver_lock('CODE1')" | Out-Null
} catch {}
