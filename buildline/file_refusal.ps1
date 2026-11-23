$key = $env:SBKEY
$h = @{ Authorization = 'Bearer ' + $key; apikey = $key; 'Content-Type' = 'application/json' }
$b = $env:BOARD_ID
$title = $env:REFUSAL_TITLE
$detail = $env:REFUSAL_DETAIL
try {
    Invoke-RestMethod -Method POST -Uri ($env:SBURL + '/rest/v1/rpc/take_look') -Headers $h -Body (ConvertTo-Json @{ p_subject = $title } -Compress) | Out-Null
    $ba = @{ p_title = $title; p_turn = 'OPUS'; p_actor = 'CODE'; p_priority = 1; p_detail = $detail; p_ref = [int]$b; p_plan_id = 3590 }
    $r = Invoke-RestMethod -Method POST -Uri ($env:SBURL + '/rest/v1/rpc/board_add') -Headers $h -Body (ConvertTo-Json $ba -Compress)
    Write-Host ('Filed as board ' + ($r.id))
} catch {
    Write-Host ('Failed to file: ' + $_)
}
