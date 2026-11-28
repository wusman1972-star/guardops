# Files a fix board (turn CODE) when the severity gate holds a merge.
# Env vars required: SBKEY, SBURL, BOARD_ID, SEVSTOP, GOPS_REPO
#
# 26 Nov 2026, hole 869: this used to POST to /rest/v1/rpc/take_look and
# /rest/v1/rpc/board_add. Both doors were cut on 18 November - their bodies
# still query dropped tables - and PostgREST answers an unusable RPC with 404,
# so every single held merge printed "Failed to file hold board: (404) Not
# Found" and nothing was ever written to the floor. It now inserts straight
# into guardops.board_item, which is how every board has been filed since the
# cut, and the dead take_look call is gone - take_look does not work and the
# look-first rule it served is not in force.
$key = $env:SBKEY
$h = @{
    Authorization  = 'Bearer ' + $key
    apikey         = $key
    'Content-Type' = 'application/json'
    Prefer         = 'return=representation'
    'Accept-Profile' = 'guardops'
    'Content-Profile' = 'guardops'
}
$b = $env:BOARD_ID
$count = $env:SEVSTOP

$findingLines = @()
$verdictFile = 'unknown'

try {
    $dir = Join-Path $env:GOPS_REPO 'tools\verdicts'
    $files = @(Get-ChildItem -Path $dir -Filter ("cr_verdict_" + $b + "_*") -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime)
    foreach ($file in $files) {
        $lines = Get-Content -LiteralPath $file.FullName
        $finished = $false
        $fileFindings = @()
        foreach ($line in $lines) {
            $t = $line.Trim()
            if (-not $t.StartsWith('{')) { continue }
            try { $o = $t | ConvertFrom-Json } catch { continue }
            if ($o.type -eq 'complete' -and $o.status -eq 'review_completed') { $finished = $true }
            if ($o.type -eq 'finding' -and ($o.severity -eq 'critical' -or $o.severity -eq 'major')) {
                $sev = $o.severity.ToUpper()
                $fn  = if ($o.fileName) { $o.fileName } else { 'unknown file' }
                $ttl = if ($o.title)    { $o.title }    else { '(no title)' }
                $fileFindings += "${sev} in ${fn}: ${ttl}"
            }
        }
        if ($finished -and $fileFindings.Count -gt 0) {
            $verdictFile = $file.Name
            $findingLines += $fileFindings
        }
    }
} catch {
    $findingLines += ('Could not read verdict files: ' + $_)
}

if ($findingLines.Count -eq 0) {
    $findingLines += 'Finding details could not be extracted from verdict files.'
}

$body   = $findingLines -join "`n"
$title  = "FIX NEEDED: board $b held - $count critical/major finding(s)"
$detail = "Board $b was held by the severity gate: $count critical/major finding(s).`n`nVerdict file: $verdictFile`n`nFindings:`n$body`n`nFix the fault(s) and open a new board to carry the corrected work."

try {
    $row = @{
        account_id = 1
        title      = $title
        detail     = $detail
        status     = 'OPEN'
        turn       = 'CODE'
        priority   = 1
        created_by = 'CODE'
        last_actor = 'CODE'
        parent_board_id = [int]$b
    }
    $r = Invoke-RestMethod -Method POST -Uri ($env:SBURL + '/rest/v1/board_item') -Headers $h -Body (ConvertTo-Json @($row) -Compress)
    if ($r -and $r[0].id) {
        Write-Host ('Filed as board ' + $r[0].id)
    } else {
        Write-Host 'Filed as board (id not returned)'
    }
} catch {
    Write-Host ('Failed to file hold board: ' + $_)
}
