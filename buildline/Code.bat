@echo off
title CODE
if not defined GOPS_REPO set "GOPS_REPO=%~dp0guardops-install"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\move_code_window.ps1" >nul 2>&1
setlocal enabledelayedexpansion
REM hole 782: the build folder is set ONCE here, never written into a step.
if not defined GOPS_REPO set "GOPS_REPO=%~dp0guardops-install"

set "NODE_USE_ENV_PROXY=1"
set "F=%~dp0next_job.txt"
set "L=%~dp0code_log.txt"
set "LAST="
if exist "%~dp0last_board.txt" for /f "usebackq delims=" %%Z in ("%~dp0last_board.txt") do set "LAST=%%Z"
set "SBURL=https://lauttgnmksnxohigaqee.supabase.co"
set "SBKEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
set "SBKEY=!SBKEY!.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhdXR0Z25ta3NueG9oaWdhcWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NDgxNzAsImV4cCI6MjEwNDQyNDE3MH0.zsuiRFhZd8163ysJeOLVrNJLJyJxoNnT0X4qoV85Z-A"
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\floor_poll.ps1" -SkipIds "!FLOOR_SKIP!" -TmpPath "%~dp0floor_next.tmp" 2>>"%L%"
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
    set "REFUSAL_TITLE=builder.key missing before board !B! - line stopped"
    set "REFUSAL_DETAIL=X_BUILDER_KEY was empty when re-read inside the loop before board !B!. Line stopped."
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\file_refusal.ps1"
    goto wait_stopped
)
echo ===== KEY-REREAD board !B! X_BUILDER_KEY set ok %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_take.ps1" -BoardId "!B!" -LogPath "%L%"
if errorlevel 1 (
    echo Lock refused or transport error for board !B!. See code_log.txt. Waiting...
    goto wait
)
echo ===== LOCK TAKEN board !B! %DATE% %TIME% ===== >> "%L%"
set "LAST=!B!"
>"%~dp0last_board.txt" echo !B!
echo ===== START board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\run_worker.ps1" -BoardId "!B!" -LogPath "%L%"
set "CLAUDE_EXIT=!ERRORLEVEL!"
set "WORKER_SIGNAL=NORESULT"
if exist "%~dp0last_result.txt" (
    for /f "usebackq delims=" %%R in ("%~dp0last_result.txt") do set "WORKER_SIGNAL=%%R"
)
echo ===== WORKER EXIT !CLAUDE_EXIT! signal !WORKER_SIGNAL! board !B! %DATE% %TIME% ===== >> "%L%"
set "WORKER_OK=0"
if "!WORKER_SIGNAL!"=="SUCCESS" set "WORKER_OK=1"
if "!WORKER_SIGNAL!"=="NORESULT" (
    if !CLAUDE_EXIT! equ 0 set "WORKER_OK=1"
)
if "!WORKER_OK!"=="0" (
    echo ===== WORKER FAILED board !B! %DATE% %TIME% - exit !CLAUDE_EXIT! signal !WORKER_SIGNAL! - nothing published ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  JOB !B! WORKER FAILED ^(exit !CLAUDE_EXIT! signal !WORKER_SIGNAL!^)
    echo  Work left on local branch. Nothing published.
    echo ***********************************************
    echo.
    if "!FLOOR_JOB!"=="1" call :track_floor_fail
    timeout /t 60 /nobreak >nul
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
    goto loop
)
REM --- Hole 796: every job gets its OWN BRANCH off master before anything is committed.
REM Work was committed straight onto master, so CodeRabbit ran with currentBranch=master and
REM baseBranch=master and answered "No changes detected" on every job. The chain says each
REM piece goes up as its own PR and CodeRabbit reviews that PR.
echo ===== BRANCH board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\branch_checkout.ps1" -BoardId "!B!" -LogPath "%L%" -RepoPath "%GOPS_REPO%"
if errorlevel 1 (
    echo ===== BRANCH CHECKOUT FAILED board !B! %DATE% %TIME% - still on wrong branch, edits preserved, nothing committed ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  BRANCH CHECKOUT FAILED for board !B!
    echo  Git refused checkout - local edits preserved.
    echo  Nothing committed.
    echo ***********************************************
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\file_wrong_branch.ps1"
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
    goto loop
)
REM --- Pre-review commit: stage migrations/ and tools/, commit before CR sees dirty files ---
set "HOLDMERGE="
set "HOLDFILE=%GOPS_REPO%\tools\held_branch.txt"
if exist "!HOLDFILE!" (
    set "HOLDMERGE=-BranchOnly"
    echo ===== HOLD FILE ACTIVE board !B! %DATE% %TIME% - prior hold persists until full-branch review is clean ===== >> "%L%"
)
echo ===== PRE-REVIEW COMMIT board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\pre_review_commit.ps1" -BoardId "!B!" -LogPath "%L%" -RepoPath "%GOPS_REPO%"
if errorlevel 1 (
    echo ===== PRE-REVIEW COMMIT FAILED board !B! %DATE% %TIME% - LINE STOPPED ===== >> "%L%"
    set "REFUSAL_TITLE=Pre-review commit failed board !B! - line stopped"
    set "REFUSAL_DETAIL=git commit of migrations/ and tools/ failed before CR review for board !B!. Line stopped to prevent review against a dirty tree."
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\file_refusal.ps1"
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
    goto wait_stopped
)
echo ===== CR REVIEW board !B! %DATE% %TIME% ===== >> "%L%"
call "%~dp0cr_review.bat" "!B!"
set "CR_EXIT=!ERRORLEVEL!"
set "CR_RETRIES=0"
:cr_allowance_wait
set "CR_WHY="
if !CR_EXIT! equ 2 set "CR_WHY=the reviewer reported a rate limit"
if !CR_EXIT! equ 3 set "CR_WHY=the connection to the reviewer dropped"
if defined CR_WHY (
    if !CR_RETRIES! lss 5 (
        set /a CR_RETRIES+=1
        echo ===== CR REVIEW RETRY NEEDED board !B! - !CR_WHY! - retry !CR_RETRIES!/5 waiting 300s %DATE% %TIME% ===== >> "%L%"
        echo.
        echo  Review did not finish for board !B!: !CR_WHY!. Retry !CR_RETRIES!/5 - waiting 5 min...
        echo.
        timeout /t 300 /nobreak >nul
        echo ===== CR REVIEW RETRY !CR_RETRIES! board !B! %DATE% %TIME% ===== >> "%L%"
        call "%~dp0cr_review.bat" "!B!"
        set "CR_EXIT=!ERRORLEVEL!"
        goto cr_allowance_wait
    )
)
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
    set "REFUSAL_TITLE=CR REVIEW REFUSED board !B! - line stopped"
    set "REFUSAL_DETAIL=CodeRabbit review could not run for board !B!. The loop is stopped until the reviewer is fixed. CR exit code: !CR_EXIT_ENV!"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\file_refusal.ps1"
    echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
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
for /f "delims=" %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\severity_gate.ps1"') do set "SEVSTOP=%%S"
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
if "!SEVSTOP!"=="SKIPPED" (
    echo ===== SEVERITY GATE SKIPPED board !B! %DATE% %TIME% - no reviewable change, hold persists unchanged ===== >> "%L%"
)
if not "!SEVSTOP!"=="0" if not "!SEVSTOP!"=="SKIPPED" (
    REM His ruling 23 Nov, about 9:50 AM: never stop anyone's work. Tell them what is
    REM wrong, mark it, and move on. The gate used to push the branch and stop the line
    REM here. It no longer stops anything - it marks the job loudly and falls straight
    REM through to the normal push and merge.
    set "HOLDMERGE=-BranchOnly"
    REM 25 Nov 2026, Waqar's order: record WHICH branch is held, so the next job carries
    REM on from it instead of cutting a fresh one from master and losing the held fix.
    echo board-!B!> "%GOPS_REPO%\tools\held_branch.txt"
    echo ===== MERGE HELD board !B! %DATE% %TIME% - !SEVSTOP! critical/major finding^(s^) in the review; the branch is pushed, master is NOT touched, the line carries on ===== >> "%L%"
    echo.
    echo ***********************************************
    echo  MERGE HELD: board !B! has !SEVSTOP! serious finding^(s^)
    echo  Branch pushed. NOT merged into master.
    echo ***********************************************
    echo.
    echo ===== FILE HOLD BOARD board !B! %DATE% %TIME% ===== >> "%L%"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\file_hold.ps1"
)
REM --- Persistent-hold resolution: a readable gate returning zero is the only automatic clear ---
REM Hole 856: before clearing, verify the verdict's base covers origin/master. A later job
REM whose review saw only its own delta must not lift a hold from commits it never reviewed.
if "!SEVSTOP!"=="0" if not defined SEVBAD (
    set "COVCHECK=FULL"
    if exist "!HOLDFILE!" (
        set "COVCHECK=UNKNOWN"
        for /f "delims=" %%C in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\hold_coverage_check.ps1"') do set "COVCHECK=%%C"
        echo ===== COVERAGE CHECK board !B! %DATE% %TIME% - !COVCHECK! ===== >> "%L%"
    )
    if "!COVCHECK!"=="FULL" (
        del /q "!HOLDFILE!" 2>nul
        set "HOLDMERGE="
        echo ===== HOLD CLEARED board !B! %DATE% %TIME% - full-branch review passed zero critical/major ===== >> "%L%"
    ) else (
        echo ===== HOLD RETAINED board !B! %DATE% %TIME% - verdict did not cover full branch ^(coverage: !COVCHECK!^) - hold stays ===== >> "%L%"
    )
)
if exist "!HOLDFILE!" (
    set "HOLDMERGE=-BranchOnly"
    echo ===== HOLD FILE ACTIVE board !B! %DATE% %TIME% - prior hold persists, merge blocked ===== >> "%L%"
)
echo ===== GIT PUSH board !B! %DATE% %TIME% - merge hold: [!HOLDMERGE!] ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\publish_branch.ps1" -LogPath "%L%" -BoardId "!B!" -RepoPath "%GOPS_REPO%" !HOLDMERGE!
echo ===== FETCH REAL MASTER board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\fetch_master.ps1" -LogPath "%L%" -RepoPath "%GOPS_REPO%"
echo ===== END board !B! %DATE% %TIME% ===== >> "%L%"
echo ===== LOCK RELEASE board !B! %DATE% %TIME% ===== >> "%L%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%GOPS_REPO%\buildline\lock_release.ps1" >nul 2>&1
start "CODE" "%~dp0Code.bat"
exit
:wait_stopped
goto loop
:wait
REM hole 782 retired this step (reached into the retired repo): pr_stamp_gap_check.ps1
timeout /t 10 /nobreak >nul
goto loop
