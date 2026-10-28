@echo off
setlocal
chcp 65001 >nul
title GovConnect - Device Mode Launcher
cd /d "%~dp0"

echo ================================================
echo   GovConnect - Device mode (API + tunnel HTTPS + Mini App QR)
echo ================================================
echo.

REM --- 1) Ha tang Docker: Postgres 5432/5442, MinIO 9000-9001, Redis 6379 ---
echo [1/5] Khoi dong Docker (Postgres, MinIO, Redis)...
docker compose -p govconnect up -d --wait
if errorlevel 1 (
  echo.
  echo [LOI] Docker chua san sang. Hay mo Docker Desktop roi chay lai file nay.
  pause
  exit /b 1
)
echo     Docker OK.
echo.

REM --- 2) Firewall: cho dien thoai cung Wi-Fi (hoac tien trinh local) vao cong 8310 ---
echo [2/5] Kiem tra firewall rule cho cong 8310...
powershell -NoProfile -Command "if (-not (Get-NetFirewallRule -DisplayName 'GovConnect API dev (8310)' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName 'GovConnect API dev (8310)' -Direction Inbound -Protocol TCP -LocalPort 8310 -Action Allow -Profile Any | Out-Null; Write-Host '    Da tao firewall rule.' } else { Write-Host '    Firewall rule da co san.' }"
echo.

REM --- 3) API .NET, bind 0.0.0.0 de tunnel/LAN vao duoc (khong chi localhost) ---
echo [3/5] Mo cua so API .NET (0.0.0.0:8310)...
start "GovConnect API :8310" cmd /k "dotnet run --project src/GovConnect.Api -- --urls http://0.0.0.0:8310"

REM --- 4) Tunnel HTTPS cho API, subdomain co dinh khop VITE_API_BASE trong miniapp/.env.development.local ---
echo [4/5] Mo tunnel HTTPS cho API (https://govconnect-api-dev.mini.123c.vn)...
start "GovConnect API tunnel" /D "%~dp0miniapp" cmd /k "npx localtunnel --port 8310 --host https://mini.123c.vn --subdomain govconnect-api-dev"

REM Tao file override neu chua co (khong ghi de neu ban da tuy chinh san)
if not exist "%~dp0miniapp\.env.development.local" (
  > "%~dp0miniapp\.env.development.local" echo VITE_API_BASE=https://govconnect-api-dev.mini.123c.vn
  echo     Da tao miniapp\.env.development.local
)

REM --- 5) Doi API + tunnel san sang roi mo Mini App device mode (in QR de quet) ---
echo [5/5] Cho 8 giay de API + tunnel len, roi mo Mini App (device mode)...
timeout /t 8 /nobreak >nul
start "GovConnect MiniApp (device)" /D "%~dp0miniapp" cmd /k "npx zmp start -D"

echo.
echo ================================================
echo   Da mo 3 cua so: API, Tunnel, Mini App (device mode).
echo   Doi vai giay roi quet ma QR trong cua so "Mini App (device)"
echo   bang app Zalo. Dien thoai chi can co Internet (mini app tai
echo   qua tunnel cong khai cua zmp-cli, khong bat buoc cung Wi-Fi
echo   voi may nay, nhung API thi luon qua tunnel HTTPS o buoc 4).
echo.
echo   Dong cua so nao chi tat rieng phan do. Muon dung het,
echo   dong ca 3 cua so + chay stop-dev.bat de tat Docker.
echo ================================================
echo.
pause
endlocal
