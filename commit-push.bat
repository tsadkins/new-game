@echo off
REM Git Commit and Push Script for Work PC
REM Automates committing changes to GitHub with optional custom message
REM Repository: https://github.com/tsadkins/new-game

set "REPO_PATH=C:\Users\tadkins\Documents\new-game-project"
set "DEFAULT_COMMIT_MSG=Grok: Update new-game-project"

echo ==========================================
echo Git Commit and Push - WORK PC Mode
echo ==========================================
echo.
echo Repository: https://github.com/tsadkins/new-game
echo.

REM Navigate to repo directory
cd /d "%REPO_PATH%" >nul

echo [1/4] Checking for changes...
git status --porcelain >nul 2>&1

if %errorLevel% equ 0 (
    echo ✓ No uncommitted changes found!
) else (
    echo ⚠️  Changes detected:
    git status --porcelain
    
    echo.
    echo ==========================================
    echo Commit Message Options:
    echo ==========================================
    echo A) Use default message: "%DEFAULT_COMMIT_MSG%"
    echo B) Enter custom commit message
    echo C) Skip commit (just push existing commits)
    echo.
    
    set /p COMMIT_CHOICE="Enter choice (A/B/C, or press Enter for A): "
    
    if /i "%COMMIT_CHOICE%"=="" (
        set "COMMIT_CHOICE=A"
    )
    
    if /i "%COMMIT_CHOICE%"=="C" (
        echo Skipping commit...
        goto :PUSH_ONLY
    ) else if /i "%COMMIT_CHOICE%"=="A" (
        set "COMMIT_MSG=%DEFAULT_COMMIT_MSG%"
    ) else if /i "%COMMIT_CHOICE%"=="B" (
        set /p COMMIT_MSG="Enter custom commit message: "
    ) else (
        echo Invalid choice. Using default message.
        set "COMMIT_MSG=%DEFAULT_COMMIT_MSG%"
    )
    
    echo [2/4] Staging all changes...
    git add . 2>&1 | findstr /v "^$" >nul
    
    if %errorLevel% neq 0 (
        echo ERROR: Failed to stage changes!
        pause
        exit /b 1
    )
    
    echo ✓ Changes staged successfully.
    echo.
    
    echo [3/4] Committing changes...
    git commit -m "%COMMIT_MSG%" 2>&1 | findstr /v "^$" >nul
    
    if %errorLevel% neq 0 (
        echo ERROR: Failed to commit! Check the error messages above.
        pause
        exit /b 1
    )
    
    echo ✓ Changes committed successfully.
)

echo [4/4] Pushing to GitHub...
git push origin main 2>&1 | findstr /v "^$" >nul

if %errorLevel% equ 0 (
    echo.
    echo ==========================================
    echo SUCCESS! Changes pushed to GitHub.
    echo Repository: https://github.com/tsadkins/new-game
    echo ==========================================
) else (
    echo.
    echo ERROR: Push failed! Check the error messages above.
    echo Possible reasons:
    echo   - Not logged into GitHub
    echo   - No permission to push
    echo   - Merge conflicts with remote branch
    pause
    exit /b 1
)

echo.
pause