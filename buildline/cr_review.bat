@echo off
REM cr_review.bat - run the CodeRabbit CLI and write a per-job verdict file.
REM Usage: cr_review.bat [board_number]
REM Writes tools\verdicts\cr_verdict_<board>_<timestamp>.txt and copies to cr_last.txt.
setlocal enabledelayedexpansion
if not defined GOPS_REPO set "GOPS_REPO=%~dp0guardops-install"
set "REPO=%GOPS_REPO%"
set "BOARD=%~1"
if "%BOARD%"=="" set "BOARD=unknown"
cd /d "%REPO%" || exit /b 1
if not exist tools mkdir tools
if not exist tools\verdicts mkdir tools\verdicts
for /f "tokens=*" %%T in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"') do set "TS=%%T"
set "VF=tools\verdicts\cr_verdict_%BOARD%_%TS%.txt"
del /q tools\cr_done.flag 2>nul
echo running > tools\cr_running.flag
set "PREVHEAD="
if exist tools\cr_reviewed_head.txt for /f "usebackq tokens=1" %%P in ("tools\cr_reviewed_head.txt") do set "PREVHEAD=%%P"
for /f "tokens=*" %%H in ('git rev-parse HEAD 2^>nul') do set "CURHEAD=%%H"
REM board 4305: the whole-branch review refuses when the branch carries more files than the
REM reviewer accepts (1,965 vs a 300 cap while the schema export is unmerged). Review the
REM scopes that fit, one after the other, and never supabase/schemas, which is generated
REM and proven by byte comparison instead (board 4297).
REM Waqar ordered this 4:55 PM PKT 15 Nov: fastest safe route, unattended. Review every
REM top-level folder this branch actually changed - no folder a job touched is skipped, and
REM no folder it never touched is read. Reading the 110-file tools folder on every job was
REM costing most of the wall clock. supabase/schemas is excluded: generated, and proven by
REM byte comparison instead (board 4297, hole 548).
set "RC=0"
if exist "%TEMP%\cr_scopes.tmp" del /q "%TEMP%\cr_scopes.tmp"
set "BASEREF="
REM Base the review on the LAST REVIEWED HEAD, not on origin/master: the job pushes
REM before the reviewer runs, so origin/master already held the change and the diff
REM came back empty every time - three jobs reviewed nothing on 22 Nov.
if defined PREVHEAD git cat-file -e !PREVHEAD! >nul 2>&1 && set "BASEREF=!PREVHEAD!"
for %%B in (origin/master origin/main master main) do (
    if not defined BASEREF git rev-parse --verify %%B >nul 2>&1 && set "BASEREF=%%B"
)
if not defined BASEREF set "BASEREF=HEAD~1"
echo ===== base !BASEREF! ===== >> "%VF%"
git diff --name-only !BASEREF!...HEAD > "%TEMP%\cr_diff1.tmp" 2> "%TEMP%\cr_diff1_err.tmp"
if errorlevel 1 (
    echo ===== git diff failed: base !BASEREF! could not be resolved ===== >> "%VF%"
    type "%TEMP%\cr_diff1_err.tmp" >> "%VF%"
    del /q "%TEMP%\cr_diff1.tmp" "%TEMP%\cr_diff1_err.tmp" 2>nul
    copy /y "%VF%" tools\cr_last.txt >nul 2>&1
    del /q tools\cr_running.flag 2>nul
    echo 1 > tools\cr_done.flag
    exit /b 1
)
for /f "usebackq delims=" %%F in ("%TEMP%\cr_diff1.tmp") do (
    set "FSKIP="
    if /i "%%F"=="tools/cr_last.txt" set "FSKIP=reviewer state file"
    if /i "%%F"=="tools/cr_done.flag" set "FSKIP=reviewer state file"
    if /i "%%F"=="tools/cr_running.flag" set "FSKIP=reviewer state file"
    if /i "%%F"=="tools/cr_reviewed_head.txt" set "FSKIP=reviewer state file"
    echo %%F| findstr /i /b "tools/verdicts/" >nul 2>&1
    if not errorlevel 1 set "FSKIP=reviewer state file"
    echo %%F| findstr /i /b "supabase/schemas/" >nul 2>&1
    if not errorlevel 1 set "FSKIP=supabase/schemas is generated - skipped by design (board 4297)"
    if defined FSKIP (
        echo SKIPPED [!FSKIP!]: %%F>> "%VF%"
    ) else (
        echo %%F| findstr /c:"/" >nul 2>&1
        if errorlevel 1 (
            echo .>> "%TEMP%\cr_scopes.tmp"
        ) else (
            for /f "tokens=1 delims=/" %%T in ("%%F") do (
                if /i "%%T"=="supabase" (
                    for /f "tokens=1,2 delims=/" %%A in ("%%F") do (
                        if "%%B"=="" (
                            echo %%A>> "%TEMP%\cr_scopes.tmp"
                        ) else if exist "%%A\%%B\" (
                            echo %%A/%%B>> "%TEMP%\cr_scopes.tmp"
                        ) else (
                            echo %%A>> "%TEMP%\cr_scopes.tmp"
                        )
                    )
                ) else (
                    echo %%T>> "%TEMP%\cr_scopes.tmp"
                )
            )
        )
    )
)
del /q "%TEMP%\cr_diff1.tmp" "%TEMP%\cr_diff1_err.tmp" 2>nul
REM --- Hole 798: the review step was the one step with no proof on it. Work out here
REM whether this job actually changed a migrations file, so a review that read nothing
REM can be told apart from a job that genuinely had nothing to read.
set "MIGCHANGE="
git diff --name-only !BASEREF!...HEAD > "%TEMP%\cr_diff2.tmp" 2> "%TEMP%\cr_diff2_err.tmp"
if errorlevel 1 (
    echo ===== git diff failed: base !BASEREF! could not be resolved ===== >> "%VF%"
    type "%TEMP%\cr_diff2_err.tmp" >> "%VF%"
    del /q "%TEMP%\cr_diff2.tmp" "%TEMP%\cr_diff2_err.tmp" 2>nul
    copy /y "%VF%" tools\cr_last.txt >nul 2>&1
    del /q tools\cr_running.flag 2>nul
    echo 1 > tools\cr_done.flag
    exit /b 1
)
for /f "usebackq delims=" %%F in ("%TEMP%\cr_diff2.tmp") do (
    echo %%F| findstr /i /b "migrations/" >nul 2>&1
    if not errorlevel 1 set "MIGCHANGE=1"
)
del /q "%TEMP%\cr_diff2.tmp" "%TEMP%\cr_diff2_err.tmp" 2>nul
set "DIDONE="
if exist "%TEMP%\cr_scopes.tmp" (
    for /f "delims=" %%T in ('sort /unique "%TEMP%\cr_scopes.tmp" 2^>nul ^|^| sort "%TEMP%\cr_scopes.tmp"') do (
        echo !DIDONE! | findstr /c:"[%%T]" >nul || (
            set "DIDONE=!DIDONE![%%T]"
            echo ===== scope %%T ===== >> "%VF%"
            if exist "%%T\" (
                coderabbit review --agent --dir %%T >> "%VF%" 2>&1
                if errorlevel 1 set "RC=1"
            ) else (
                echo DROPPED [scope is not a directory - not reviewed]: %%T>> "%VF%"
            )
        )
    )
    del /q "%TEMP%\cr_scopes.tmp" 2>nul
)
if "!DIDONE!"=="" (
    echo ===== no reviewable change, reviewer skipped ===== >> "%VF%"
    if defined MIGCHANGE (
        echo ===== REVIEW PROOF FAILED: this job changed a migrations file and the reviewer read nothing ===== >> "%VF%"
        copy /y "%VF%" tools\cr_last.txt >nul 2>&1
        del /q tools\cr_running.flag 2>nul
        echo 1 > tools\cr_done.flag
        exit /b 1
    )
    copy /y "%VF%" tools\cr_last.txt >nul 2>&1
    del /q tools\cr_running.flag 2>nul
    echo 0 > tools\cr_done.flag
    exit /b 0
)
REM --- Tell a QUOTA apart from a BROKEN REVIEWER. A rate limit or a spending cap is not
REM --- the reviewer failing: the work is fine, the allowance is spent. Exit 2 so Code.bat
REM --- waits and retries the review instead of stopping the line and re-running the job.
REM --- Match the CLI's own error object, NOT any mention of the words. This floor's code
REM --- is full of "rate limit" (review_rate_limit, guard_review_rate_limit), so a plain
REM --- word search fires on findings text and sleeps the line for nothing.
REM --- Hole 798: CodeRabbit can run and still read nothing (currentBranch == baseBranch
REM gives "No changes detected", findings 0). On a job that changed a migrations file that
REM is a failed review, not a clean one - stop the line rather than report "reviewed".
if defined MIGCHANGE (
    findstr /i /c:"No changes detected" /c:"review_skipped" "%VF%" >nul 2>&1
    if not errorlevel 1 (
        echo ===== REVIEW PROOF FAILED: reviewer ran but read no diff on a job that changed a migrations file ===== >> "%VF%"
        copy /y "%VF%" tools\cr_last.txt >nul 2>&1
        del /q tools\cr_running.flag 2>nul
        echo 1 > tools\cr_done.flag
        exit /b 1
    )
)
findstr /r /c:"errorType.*rate_limit" /c:"Review limit reached" "%VF%" >nul 2>&1
if not errorlevel 1 set "RC=2"
if "%RC%"=="0" if defined DIDONE if defined CURHEAD echo !CURHEAD!> tools\cr_reviewed_head.txt
copy /y "%VF%" tools\cr_last.txt >nul 2>&1
del /q tools\cr_running.flag 2>nul
echo %RC% > tools\cr_done.flag
exit /b %RC%
