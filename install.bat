@echo off

echo Cleaning up old user directories...
forfiles /p "users" /d -10 /c "cmd /c if @isdir==TRUE echo @path && rmdir /s /q @path"

echo Starting Docker Compose...
docker compose up -d

if %errorlevel% neq 0 (
    echo Docker Compose failed to start.
    pause
    exit /b %errorlevel%
)

echo Docker Compose started successfully.

:check_status
for /f "tokens=2" %%i in ('docker compose ps -q shiny ^| find /c /v ""') do set count=%%i

if %count% equ 0 (
    echo The shiny service is not running.
    pause
    exit /b 1
)

docker compose ps

echo.
echo The application is running on http://localhost:3838

echo Waiting 10 seconds for the server to start...
timeout /t 10 /nobreak > nul

start http://localhost:3838

echo Press any key to stop the application and remove the containers.
pause > nul

echo Stopping Docker Compose...
docker compose down

echo Docker Compose stopped.
pause