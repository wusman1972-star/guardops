@echo off
title CODE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0move_code_window.ps1" >nul 2>&1
setlocal enabledelayedexpansion
REM hole 782: the build folder is set ONCE here, never written into a step.
if not defined GOPS_REPO set "GOPS_REPO=%~dp0guardops-install"

set "NODE_USE_ENV_PROXY=1"
set "F=%~dp0next_job.txt"
set "L=%~dp0code_log.txt"
set "LAST="
set "SBURL=https://lauttgnmksnxohigaqee.supabase.co"
set "SBKEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhdXR0Z25ta3NueG9oaWdhcWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NDgxNzAsImV4cCI6MjEwNDQyNDE3MH0.zsuiRFhZd8163ysJeOLVrNJLJyJxoNnT0X4qoV85Z-A"
set "X_BUILDER_KEY="
for /f "usebackq delims=" %%K in ("%~dp0builder.key") do set "X_BUILDER_KEY=%%K"
if "!X_BUILDER_KEY!"=="" (
    echo ERROR: builder.key missing or empty - cannot store verdicts >> "%L%"
    echo ERROR: builder.key missing or empty - cannot store verdicts
    exit /b 1
)
set "LOCK_DB_URL="
for /f "usebackq delims=" %%K in ("%~dp0lock.key") do set "LOCK_DB_URL=%%K"
if "!LOCK_DB_URL!"=="" (
    echo ERROR: lock.key missing or empty - cannot take/release build lock >> "%L%"
    echo ERROR: lock.key missing or empty - cannot take/release build lock
    exit /b 1
)
set "FLOOR_ONCE="
set "FLOOR_SKIP="
set "FLOOR_JOB=0"
REM --- Capture Code.bat fingerprint to detect stale window ---
for %%F in ("%~f0") do (set "SELF_SIZE=%%~zF" & set "SELF_TS=%%~tF")
REM --- Release any CODE1 lock left over from a force-killed window before entering the loop ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
:loop
REM --- Stale-window check ---
for %%F in ("%~f0") do (set "NOW_SIZE=%%~zF" & set "NOW_TS=%%~tF")
if not "!NOW_SIZE!"=="!SELF_SIZE!" goto stale_window
if not "!NOW_TS!"=="!SELF_TS!" goto stale_window
if not exist "%F%" goto floor_check
for /f "usebackq tokens=1,* delims=|" %%A in ("%F%") do (set "B=%%A" & set "T=%%B")
if "!B!"=="!LAST!" goto floor_check
set "FLOOR_JOB=0"
goto do_run
:floor_check
set "FLOOR_B="
set "FLOOR_T="
set "FLOOR_TMP=%~dp0floor_next.tmp"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; $skip=$env:FLOOR_SKIP; $tmp=$env:FLOOR_TMP; $skipClause=''; if ($skip -and $skip.Trim() -ne '') { $ids=($skip -split ',') | Where-Object { $_ -match '^\d+$' }; if ($ids) { $skipClause=' AND id NOT IN ('+($ids -join ',')+')' } }; $q=\"SELECT id, title FROM guardops.board_item WHERE status='OPEN' AND turn='CODE' AND priority=1 AND created_at >= NOW() - INTERVAL '7 days' AND (plan_board_id IS NULL OR plan_board_id NOT IN (SELECT id FROM guardops.board_item WHERE status IN ('DONE','FINISHED','KILLED')))$skipClause ORDER BY created_at DESC LIMIT 1\"; try { $raw=& 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -F '|' -c $q 2>&1; if ($LASTEXITCODE -eq 0) { $line=($raw | Where-Object { $_ -match '^\d+\|' } | Select-Object -First 1); if ($line) { [System.IO.File]::WriteAllLines($tmp, @($line), (New-Object System.Text.UTF8Encoding $false)) } } } catch {} }" 2>>"%L%"
set "FLOOR_B="
set "FLOOR_T="
if exist "%~dp0floor_next.tmp" (
    for /f "usebackq tokens=1,* delims=|" %%A in ("%~dp0floor_next.tmp") do (set "FLOOR_B=%%A" & set "FLOOR_T=%%B")
    del /q "%~dp0floor_next.tmp" 2>nul
)
if "!FLOOR_B!"=="" goto wait
set "B=!FLOOR_B!"
set "T=!FLOOR_T!"
set "FLOOR_JOB=1"
:do_run
echo.
echo ===============================================
echo  Board !B! - !T!
echo ===============================================
echo.
set "BOARD_ID=!B!"
REM --- Re-read builder.key before this job ---
set "X_BUILDER_KEY="
for /f "usebackq delims=" %%K in ("%~dp0builder.key") do set "X_BUILDER_KEY=%%K"
if "!X_BUILDER_KEY!"=="" (
    echo ===== ERROR: builder.key empty or missing - board !B! - line stopped %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $key=$env:SBKEY; $h=@{Authorization='Bearer '+$key;apikey=$key;'Content-Type'='application/json'}; $b=$env:BOARD_ID; $title='builder.key missing before board '+$b+' - line stopped'; $detail='X_BUILDER_KEY was empty when re-read inside the loop before board '+$b+'. Line stopped.'; try { Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/take_look') -Headers $h -Body (ConvertTo-Json @{p_subject=$title} -Compress) | Out-Null; $ba=@{p_title=$title;p_turn='OPUS';p_actor='CODE';p_priority=1;p_detail=$detail;p_ref=[int]$b;p_plan_id=3590}; $r=Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/board_add') -Headers $h -Body (ConvertTo-Json $ba -Compress); Write-Host ('Filed as board '+($r.id)) } catch { Write-Host ('Failed to file: '+$_) } }"
    goto wait_stopped
)
echo ===== KEY-REREAD board !B! X_BUILDER_KEY set ok %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; $lp='%L%'; $bd=$env:BOARD_ID; try { $q='SELECT public.gops_take_driver_lock(''CODE1'','+$bd+')'; $raw=& 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c $q 2>&1; if ($LASTEXITCODE -ne 0) { throw 'psql error: '+($raw -join ' ') }; $r=($raw -join '').Trim() | ConvertFrom-Json; if ($r.ok -eq $false) { Add-Content -LiteralPath $lp -Value ('===== LOCK REFUSED board '+$bd+' %DATE% %TIME% - held by '+$r.holder+' since '+$r.since+' =====') -Encoding UTF8; exit 1 } } catch { Add-Content -LiteralPath $lp -Value ('===== LOCK TRANSPORT ERROR board '+$bd+' %DATE% %TIME% - could not reach the lock: '+$_+' =====') -Encoding UTF8; exit 1 } }"
if errorlevel 1 (
    echo Lock refused or transport error for board !B!. See code_log.txt. Waiting...
    goto wait
)
echo ===== LOCK TAKEN board !B! %DATE% %TIME% ===== >> "%L%"
set "LAST=!B!"
echo ===== START board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$lp='%L%'; $fs=New-Object System.IO.FileStream($lp,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite); $sw=New-Object System.IO.StreamWriter($fs,[System.Text.Encoding]::UTF8); $sw.AutoFlush=$true; try { claude -p 'read board !B! and do it' --verbose --output-format stream-json 2>&1 | ForEach-Object { $t=(Get-Date).ToString('HH:mm:ss'); $line=$_; if($line.Length -gt 220){$line=$line.Substring(0,220)}; $out=\"$t  $line\"; Write-Host $out; $sw.WriteLine($out) } } finally { $sw.Close(); $fs.Dispose() }"
set "CLAUDE_EXIT=!ERRORLEVEL!"
REM --- Hole 796: every job gets its OWN BRANCH off master before anything is committed.
REM Work was committed straight onto master, so CodeRabbit ran with currentBranch=master and
REM baseBranch=master and answered "No changes detected" on every job. The chain says each
REM piece goes up as its own PR and CodeRabbit reviews that PR.
echo ===== BRANCH board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $lp='%L%'; $bd=$env:BOARD_ID; Set-Location '%GOPS_REPO%'; $br='board-'+$bd; $out = git checkout -B $br 2>&1; $out | ForEach-Object { Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8; Write-Host $_ }; Add-Content -LiteralPath $lp -Value ('ON BRANCH: '+(git rev-parse --abbrev-ref HEAD)) -Encoding UTF8 }"
REM --- Pre-review commit: stage migrations/ and tools/, commit before CR sees dirty files ---
echo ===== PRE-REVIEW COMMIT board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $lp='%L%'; $bd=$env:BOARD_ID; Set-Location '%GOPS_REPO%'; git add migrations/ tools/ 2>&1 | ForEach-Object { Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8 }; $staged=(git diff --cached --name-only); if ($staged) { $msg='board '+$bd+' job commit'; $out=git commit -m $msg 2>&1; $out | ForEach-Object { Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8; Write-Host $_ }; if ($LASTEXITCODE -ne 0) { exit 1 } else { $summary='PRE-REVIEW COMMIT OK: '+($staged -join ', '); Add-Content -LiteralPath $lp -Value $summary -Encoding UTF8; Write-Host $summary } } else { Add-Content -LiteralPath $lp -Value 'PRE-REVIEW COMMIT: nothing to commit' -Encoding UTF8; Write-Host 'PRE-REVIEW COMMIT: nothing to commit' } }"
if errorlevel 1 (
    echo ===== PRE-REVIEW COMMIT FAILED board !B! %DATE% %TIME% - LINE STOPPED ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $key=$env:SBKEY; $h=@{Authorization='Bearer '+$key;apikey=$key;'Content-Type'='application/json'}; $b=$env:BOARD_ID; $title='Pre-review commit failed board '+$b+' - line stopped'; $detail='git commit of migrations/ and tools/ failed before CR review for board '+$b+'. Line stopped to prevent review against a dirty tree.'; try { Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/take_look') -Headers $h -Body (ConvertTo-Json @{p_subject=$title} -Compress) | Out-Null; $ba=@{p_title=$title;p_turn='OPUS';p_actor='CODE';p_priority=1;p_detail=$detail;p_ref=[int]$b;p_plan_id=3590}; $r=Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/board_add') -Headers $h -Body (ConvertTo-Json $ba -Compress); Write-Host ('Filed as board '+($r.id)) } catch { Write-Host ('Failed to file: '+$_) } }"
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
    goto wait_stopped
)
echo ===== CR REVIEW board !B! %DATE% %TIME% ===== >> "%L%"
call "%~dp0cr_review.bat" "!B!"
set "CR_EXIT=!ERRORLEVEL!"
if !CR_EXIT! neq 0 (
    echo ===== CR REVIEW REFUSED board !B! %DATE% %TIME% - LINE STOPPED ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  REVIEW COULD NOT RUN for board !B! ^(exit !CR_EXIT!^)
    echo  The line is stopped. Fix the reviewer before
    echo  the next job starts.
    echo ***********************************************
    echo.
    set "CR_EXIT_ENV=!CR_EXIT!"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $key=$env:SBKEY; $h=@{Authorization='Bearer '+$key;apikey=$key;'Content-Type'='application/json'}; $b=$env:BOARD_ID; $title='CR REVIEW REFUSED board '+$b+' - line stopped'; $detail='CodeRabbit review could not run for board '+$b+'. The loop is stopped until the reviewer is fixed. CR exit code: '+$env:CR_EXIT_ENV; try { Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/take_look') -Headers $h -Body (ConvertTo-Json @{p_subject=$title} -Compress) | Out-Null; $ba=@{p_title=$title;p_turn='OPUS';p_actor='CODE';p_priority=1;p_detail=$detail;p_ref=[int]$b;p_plan_id=3590}; $r=Invoke-RestMethod -Method POST -Uri ($env:SBURL+'/rest/v1/rpc/board_add') -Headers $h -Body (ConvertTo-Json $ba -Compress); Write-Host ('Refusal filed as board '+($r.id)) } catch { Write-Host ('Failed to file refusal: '+$_) } }"
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
    goto wait_stopped
)
REM --- Store per-file verdicts for files reviewed this run (board 4075) ---
echo ===== CR STORE VERDICTS board !B! %DATE% %TIME% ===== >> "%L%"
REM hole 782 retired this step (reached into the retired repo): node "%~dp0flowops-guardops-sql\tools\store_cr_verdicts.mjs" >> "%L%" 2>&1
REM --- SEVERITY GATE (his ruling 22 Nov, ~10:10 PM): a Critical or Major finding holds
REM the merge. Read straight out of the newest verdict file for this board - no judgement,
REM no model call. Minor, trivial and nit hold nothing. The branch is still pushed so no
REM work is lost; only the merge into master is held, and the line stops so the next job
REM cannot build on top of it. This gate only READS - it never refuses a write anywhere.
set "SEVSTOP="
for /f "delims=" %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0severity_gate.ps1"') do set "SEVSTOP=%%S"
echo ===== SEVERITY GATE board !B! %DATE% %TIME% - critical/major count: !SEVSTOP! ===== >> "%L%"
REM An unreadable gate must not brick the line. It waves the job through and SHOUTS, so the
REM next window sees it at once instead of a silent pass. Three ways it can be unreadable:
REM no verdict file at all, a verdict from a review killed before it finished, or the reader
REM itself failing. None of them may pass quietly as a clean zero.
set "SEVBAD="
if "!SEVSTOP!"=="NOVERDICT" set "SEVBAD=no verdict file for this board"
if "!SEVSTOP!"=="NOTCOMPLETE" set "SEVBAD=the review was killed before it finished - the verdict is not complete"
if "!SEVSTOP!"=="" set "SEVBAD=the reader returned nothing"
if defined SEVBAD (
    echo ===== SEVERITY GATE COULD NOT READ THE VERDICT board !B! %DATE% %TIME% - !SEVBAD! - GATE IS NOT WORKING, FIX IT ===== >> "%L%"
    set "SEVSTOP=0"
)
if not "!SEVSTOP!"=="0" (
    REM His ruling 23 Nov, about 9:50 AM: never stop anyone's work. Tell them what is
    REM wrong, mark it, and move on. The gate used to push the branch and stop the line
    REM here. It no longer stops anything - it marks the job loudly and falls straight
    REM through to the normal push and merge.
    echo ===== MARKED board !B! %DATE% %TIME% - !SEVSTOP! critical/major finding^(s^) in the review; work carries on, see the verdict file ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  MARKED: board !B! has !SEVSTOP! serious finding^(s^)
    echo  Nothing is held. The work carries on.
    echo ***********************************************
    echo.
)
echo ===== GIT PUSH board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $lp='%L%'; $bd=$env:BOARD_ID; Set-Location '%GOPS_REPO%'; $br='board-'+$bd; $out=git push origin HEAD 2>&1; $out|ForEach-Object{Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8;Write-Host $_}; if($LASTEXITCODE -ne 0){Add-Content -LiteralPath $lp -Value ('BRANCH PUSH FAILED for '+$br+' - branch not landed') -Encoding UTF8;return}; $out=git checkout master 2>&1; $out|ForEach-Object{Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8;Write-Host $_}; if($LASTEXITCODE -ne 0){Add-Content -LiteralPath $lp -Value ('CHECKOUT MASTER FAILED for '+$br+' - branch not landed') -Encoding UTF8;return}; $out=git merge --ff-only $br 2>&1; $out|ForEach-Object{Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8;Write-Host $_}; if($LASTEXITCODE -ne 0){Add-Content -LiteralPath $lp -Value ('MERGE TO MASTER FAILED for '+$br+' - branch left unmerged') -Encoding UTF8;return}; $out=git push origin master 2>&1; $out|ForEach-Object{Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8;Write-Host $_}; if($LASTEXITCODE -ne 0){Add-Content -LiteralPath $lp -Value ('MASTER PUSH FAILED for '+$br+' - merged locally not pushed') -Encoding UTF8;return}; Add-Content -LiteralPath $lp -Value ('MERGED AND PUSHED: '+$br+' -> master') -Encoding UTF8 }"
echo ===== FETCH REAL MASTER board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $lp='%L%'; Set-Location '%GOPS_REPO%'; $out = git fetch origin master:refs/remotes/origin-real-master 2>&1; $out | ForEach-Object { Add-Content -LiteralPath $lp -Value $_ -Encoding UTF8; Write-Host $_ } }"
if !CLAUDE_EXIT! neq 0 (
    echo ===== FAILED board !B! %DATE% %TIME% ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  JOB !B! DID NOT FINISH PROPERLY
    echo  Retrying poll in 60 seconds...
    echo ***********************************************
    echo.
    if "!FLOOR_JOB!"=="1" call :track_floor_fail
    timeout /t 60 /nobreak >nul
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
    goto loop
)
echo ===== END board !B! %DATE% %TIME% ===== >> "%L%"
echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
echo.
echo Job !B! finished. Waiting for the next one...
goto loop
:track_floor_fail
echo ,!FLOOR_ONCE!, > "%~dp0_fl_chk.tmp"
findstr /c:",!B!," "%~dp0_fl_chk.tmp" >nul 2>&1
if errorlevel 1 (
    if "!FLOOR_ONCE!"=="" (set "FLOOR_ONCE=!B!") else (set "FLOOR_ONCE=!FLOOR_ONCE!,!B!")
    echo ===== FLOOR JOB FAILED ONCE board !B! will retry on next pick %DATE% %TIME% ===== >> "%L%"
) else (
    if "!FLOOR_SKIP!"=="" (set "FLOOR_SKIP=!B!") else (set "FLOOR_SKIP=!FLOOR_SKIP!,!B!")
    echo ===== FLOOR JOB FAILED TWICE board !B! skip for this run %DATE% %TIME% ===== >> "%L%"
)
del /q "%~dp0_fl_chk.tmp" 2>nul
exit /b 0
:stale_window
echo ===== STALE WINDOW: Code.bat has changed - releasing lock and relaunching %DATE% %TIME% ===== >> "%L%"
echo.
echo ***********************************************
echo  STALE WINDOW: Code.bat has changed.
echo  Releasing lock and relaunching fresh window.
echo ***********************************************
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $url=$env:LOCK_DB_URL; try { & 'C:\Users\T480\scoop\apps\postgresql\current\bin\psql.exe' $url -t -A -c 'SELECT public.gops_release_driver_lock(''CODE1'')' | Out-Null } catch {} }" >nul 2>&1
start "CODE" "%~dp0Code.bat"
exit
:wait_stopped
goto loop
:wait
REM hole 782 retired this step (reached into the retired repo): if not "!X_BUILDER_KEY!"=="" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flowops-guardops-sql\tools\pr_stamp_gap_check.ps1" -LogPath "%L%" -LockDbUrl "!LOCK_DB_URL!" -SbUrl "!SBURL!" -SbKey "!X_BUILDER_KEY!" >nul 2>&1
timeout /t 10 /nobreak >nul
goto loop
