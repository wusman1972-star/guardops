param(
    [string]$BoardId,
    [string]$LogPath
)

$rp = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($LogPath), 'last_result.txt')
Remove-Item -LiteralPath $rp -ErrorAction SilentlyContinue

$fs = New-Object System.IO.FileStream($LogPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
$sw = New-Object System.IO.StreamWriter($fs, [System.Text.Encoding]::UTF8)
$sw.AutoFlush = $true

$workerExit = 0
$lastResult = $null

try {
    claude -p "read board $BoardId and do it" --verbose --output-format stream-json 2>&1 | ForEach-Object {
        $t = (Get-Date).ToString('HH:mm:ss')
        $raw = $_
        try {
            $j = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($j.type -eq 'result') { $lastResult = $j }
        } catch {}
        $line = $raw
        if ($line.Length -gt 220) { $line = $line.Substring(0, 220) }
        $out = "$t  $line"
        Write-Host $out
        $sw.WriteLine($out)
    }
    $workerExit = $LASTEXITCODE
} finally {
    $sw.Close()
    $fs.Dispose()
}

if ($lastResult) {
    if ($lastResult.is_error -eq $false -or $lastResult.subtype -eq 'success') {
        [System.IO.File]::WriteAllText($rp, 'SUCCESS')
    } else {
        [System.IO.File]::WriteAllText($rp, 'FAIL')
    }
}

exit $workerExit
