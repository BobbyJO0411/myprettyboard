# 개발 서버 한 번에 실행: DB(Docker) + 백엔드(:8000) + 웹(:3100)
# 백엔드와 웹은 각각 새 PowerShell 창에서 뜬다. 끌 때는 그 창을 닫으면 된다.
# 사용법 (프로젝트 루트에서):  powershell -ExecutionPolicy Bypass -File scripts\dev.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$env:Path = "$HOME\.local\bin;$env:Path"

Push-Location $root
docker compose up -d --wait
Pop-Location

Start-Process powershell -WorkingDirectory "$root\server" -ArgumentList "-NoExit", "-Command", "`$env:Path='$HOME\.local\bin;'+`$env:Path; uv run alembic upgrade head; uv run uvicorn server.main:app --reload"
Start-Process powershell -WorkingDirectory "$root\web" -ArgumentList "-NoExit", "-Command", "npm run dev"

Write-Host "백엔드: http://localhost:8000/docs"
Write-Host "웹:     http://localhost:3100"
