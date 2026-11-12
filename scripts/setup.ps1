# 새 PC(또는 git pull 후) 개발 환경 세팅. 여러 번 실행해도 안전하다.
# 사용법 (프로젝트 루트에서):  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$env:Path = "$HOME\.local\bin;$env:Path"   # uv 설치 직후에도 찾을 수 있게

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "X $msg" -ForegroundColor Red; exit 1 }

Step "1/6 필요한 도구 확인"
foreach ($tool in "uv", "node", "npm", "docker") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Fail "$tool 이(가) 없습니다. docs/runbook.md 의 '사전 준비'를 보고 설치하세요."
    }
}
docker info *> $null
if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop 이 실행 중이 아닙니다. 실행한 뒤 다시 시도하세요." }
Write-Host "uv, node, npm, docker OK"

Step "2/6 환경변수 파일 준비 (.env.example -> .env, 이미 있으면 건너뜀)"
$envFiles = @(
    @{ src = "$root\.env.example";        dst = "$root\.env" },
    @{ src = "$root\server\.env.example"; dst = "$root\server\.env" },
    @{ src = "$root\web\.env.example";    dst = "$root\web\.env.local" }
)
foreach ($f in $envFiles) {
    if (Test-Path $f.dst) { Write-Host "있음: $($f.dst)" }
    else { Copy-Item $f.src $f.dst; Write-Host "생성: $($f.dst)" }
}

Step "3/6 개발용 DB 실행 (Docker)"
Push-Location $root
docker compose up -d --wait
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "DB 실행 실패. 포트 충돌이면 .env 의 DB_PORT 와 server/.env 의 DATABASE_URL 포트를 바꾸세요." }
Pop-Location

Step "4/6 백엔드 의존성 설치 (uv sync)"
Push-Location "$root\server"
uv sync
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "uv sync 실패" }

Step "5/6 DB 테이블 구조 최신화 (alembic upgrade head)"
uv run alembic upgrade head
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "마이그레이션 실패. DB 연결 정보(server/.env)를 확인하세요." }
Pop-Location

Step "6/6 웹 의존성 설치 (npm install)"
Push-Location "$root\web"
npm install
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "npm install 실패" }
Pop-Location

Write-Host "`n완료! 개발 서버 실행: powershell -ExecutionPolicy Bypass -File scripts\dev.ps1" -ForegroundColor Green
