@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo Dung cac container Docker cua GovConnect (Postgres, MinIO, Redis)...
docker compose -p govconnect down
echo.
echo Xong. Du lieu Postgres/MinIO van duoc giu trong Docker volumes.
echo (Muon xoa sach ca du lieu: docker compose -p govconnect down -v)
echo.
echo Luu y: cac cua so API / Web / Mini App phai dong tay (Ctrl+C hoac dong cua so).
pause
endlocal
