# Files an alert board when branch_checkout.ps1 fails to land on the work branch.
# Env vars required: SBKEY, SBURL, BOARD_ID, GOPS_REPO
$key  = $env:SBKEY
$url  = $env:SBURL
$b    = $env:BOARD_ID
$repo = $env:GOPS_REPO

$h = @{
    Authorization    = 'Bearer ' + $key
    apikey           = $key
    'Content-Type'   = 'application/json'
    Prefer           = 'return=representation'
    'Accept-Profile'  = 'guardops'
    'Content-Profile' = 'guardops'
}

$stuck = 'unknown'
try {
    Push-Location $repo
    $stuck = (git rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
    Pop-Location
} catch { }

$title  = "BRANCH CHECKOUT FAILED: board $b - still on '$stuck', edits preserved"
$detail = "branch_checkout.ps1 could not switch to the work branch (line) for board $b.`n" +
          "Git refused the checkout because uncommitted edits on '$stuck' conflict with the work branch.`n" +
          "Local edits preserved on '$stuck'. Nothing was committed. Fix the conflict manually and retry."

try {
    $row = @{
        account_id      = 1
        title           = $title
        detail          = $detail
        status          = 'OPEN'
        turn            = 'CODE'
        priority        = 1
        created_by      = 'CODE'
        last_actor      = 'CODE'
        parent_board_id = [int]$b
    }
    $r = Invoke-RestMethod -Method POST -Uri ($url + '/rest/v1/board_item') -Headers $h -Body (ConvertTo-Json @($row) -Compress)
    if ($r -and $r[0].id) {
        Write-Host ('Filed as board ' + $r[0].id)
    } else {
        Write-Host 'Filed as board (id not returned)'
    }
} catch {
    Write-Host ('Failed to file wrong-branch board: ' + $_)
}
