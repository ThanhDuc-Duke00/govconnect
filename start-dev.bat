@echo off
setlocal
chcp 65001 >nul
title GovConnect - Dev Launcher
cd /d "%~dp0"

echo ================================================
echo   GovConnect - khoi dong moi truong DEV
echo ================================================
echo.

REM --- 1) Ha tang Docker: Postgres 5432 / MinIO 9000-9001 / Redis 6379 ---
echo [1/4] Khoi dong Docker (Postgres, MinIO, Redis)...
docker compose -p govconnect up -d --wait
if errorlevel 1 (
  echo.
  echo [LOI] Docker chua san sang. Hay mo Docker Desktop roi chay lai file nay.
  pause
  exit /b 1
)
echo     Docker OK.
echo.

REM --- 2) Tao bucket MinIO "govconnect" (idempotent, best-effort) ---
echo [2/4] Dam bao bucket MinIO "govconnect"...
docker compose -p govconnect run --rm minio-init
echo     (Neu buoc nay loi: tao tay bucket 'govconnect' tai http://localhost:9001 - minioadmin/minioadmin)
echo.

REM --- 3) API .NET  ->  http://localhost:8310  (Swagger: /swagger) ---
echo [3/4] Mo cua so API .NET (http://localhost:8310)...
start "GovConnect API :8310" cmd /k "dotnet run --project src/GovConnect.Api -- --urls http://localhost:8310"

REM --- 4) Web (:8311) + Mini App (:8312) dev servers ---
echo [4/4] Mo cua so Web (:8311) va Mini App (:8312)...
start "GovConnect Web :8311" /D "%~dp0web" cmd /k "npm run dev -- --port 8311"
start "GovConnect MiniApp :8312" /D "%~dp0miniapp" cmd /k "npm run dev -- --port 8312"

echo.
echo ================================================
echo   Dang khoi dong! Cac dia chi:
echo     API      : http://localhost:8310/swagger
echo     Web      : http://localhost:8311
echo     Mini App : http://localhost:8312
echo     MinIO    : http://localhost:9001  (minioadmin / minioadmin)
echo.
echo   Tai khoan demo (tenant demo-tandinh):
echo     admin@demo-tandinh.gov.vn / Admin@123   (TenantAdmin)
echo     super@govconnect.vn       / Super@123   (SuperAdmin)
echo ================================================
echo.
echo Dong cua so nay KHONG tat cac service.
echo De tat Docker (giu lai du lieu) chay: stop-dev.bat
echo.
pause
endlocal
