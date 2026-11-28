param(
    [string]$LogPath,
    [string]$BoardId,
    [string]$RepoPath
)

function Log([string]$msg) {
    Add-Content -LiteralPath $LogPath -Value $msg -Encoding UTF8
    Write-Host $msg
}

$resultPath = Join-Path $RepoPath 'tools\apply_result.txt'

try {
    Set-Location $RepoPath

    # Step 1: list files touched in HEAD commit, keep only migrations/*.sql
    $raw = @(& git show --name-only --pretty=format: HEAD 2>&1 | Where-Object { $_ -ne '' })
    $migrations = @($raw | Where-Object { $_ -match '^migrations/.*\.sql$' })

    if ($migrations.Count -eq 0) {
        Set-Content -LiteralPath $resultPath -Value 'NOMIGRATION' -Encoding UTF8
        Log('apply_and_prove: no migration files in HEAD - NOMIGRATION')
        exit 0
    }

    $fullPaths = ($migrations | ForEach-Object { Join-Path $RepoPath $_ }) -join ' '
    $names     = ($migrations | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }) -join ' '
    Log("apply_and_prove: $($migrations.Count) migration(s): $($migrations -join ', ')")

    # Step 2: APPLY - one worker, fixed words, no board number
    Log('apply_and_prove: apply worker start')
    & claude -p "Apply these migration files to Supabase project mfysxqhediepzohzhufp with the apply_migration tool, in filename order, only if not already applied. Then stop. Files: $fullPaths" 2>&1 |
        ForEach-Object { Log("apply: $_") }

    # Step 3: PROVE - separate worker, NOT told what the answer should be
    Log('apply_and_prove: prove worker start')
    $proveLines = @(& claude -p "Read the migration ledger of Supabase project mfysxqhediepzohzhufp (supabase_migrations.schema_migrations). Reply with one word only: LIVE if every one of these names appears in it, MISSING if any does not. Names: $names" 2>$null)
    $word = ($proveLines -join '').Trim()

    # Step 4: write exactly the word returned; anything else is UNREADABLE
    # Unreadable is never written as LIVE
    if ($word -eq 'LIVE' -or $word -eq 'MISSING') {
        Set-Content -LiteralPath $resultPath -Value $word -Encoding UTF8
    } else {
        Set-Content -LiteralPath $resultPath -Value 'UNREADABLE' -Encoding UTF8
        Log("apply_and_prove: prove output not a recognized word - UNREADABLE. Got: $word")
    }
    Log("apply_and_prove: result written: $word")

} catch {
    try { Set-Content -LiteralPath $resultPath -Value 'UNREADABLE' -Encoding UTF8 } catch {}
    Log("apply_and_prove: fault - wrote UNREADABLE. Error: $_")
}

exit 0
