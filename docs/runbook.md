# 실행 가이드 (Runbook)

## 한눈에 보기

| 상황 | 할 일 |
|---|---|
| **새 PC에서 처음 시작** | 사전 준비 → `git clone` → `scripts\setup.ps1` |
| **다른 PC에서 작업하고 돌아옴** | `git pull` → `scripts\setup.ps1` (바뀐 의존성·테이블 구조 반영) |
| **개발 서버 켜기** | `scripts\dev.ps1` |
| **작업 끝** | `git add` → `git commit` → `git push` |

## 사전 준비 (PC마다 최초 1회)

| 도구 | 확인 명령 | 설치 |
|---|---|---|
| Git | `git --version` | https://git-scm.com |
| uv | `uv --version` | `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 \| iex"` 후 터미널 새로 열기 |
| Node.js 22+ | `node -v` | https://nodejs.org |
| Docker Desktop | `docker info` | https://www.docker.com/products/docker-desktop (설치 후 실행해 둘 것) |
| GitHub CLI (선택) | `gh --version` | `winget install GitHub.cli` → `gh auth login` |

## 새 PC에서 시작하기

```powershell
git clone https://github.com/BobbyJO0411/myprettyboard.git
cd myprettyboard
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # 환경 파일, DB, 의존성, 테이블 구조까지 자동
powershell -ExecutionPolicy Bypass -File scripts\dev.ps1     # 백엔드·웹 실행
```

`setup.ps1`이 하는 일 (여러 번 실행해도 안전):

1. uv / node / npm / docker 설치 및 Docker 실행 여부 확인
2. `.env.example` → `.env` 복사 (루트, `server/`, `web/.env.local`). 이미 있으면 건너뜀
3. `docker compose up -d --wait` — 개발용 DB 실행
4. `uv sync` — 백엔드 의존성 설치
5. `uv run alembic upgrade head` — DB 테이블 구조를 최신으로
6. `npm install` — 웹 의존성 설치

## DB 구조 이해하기

| | 개발용 DB | 운영용 DB (예정) |
|---|---|---|
| 위치 | **PC마다** Docker 컨테이너 | **서버 한 곳** |
| 데이터 | 테스트 데이터, 지워도 됨 | 진짜 내 데이터 |
| PC 간 공유 | 데이터는 공유하지 않음. **테이블 구조(마이그레이션)만 git으로 공유** | 웹·모바일·모든 PC가 여기 접속 |

이유는 [ADR 0004](decisions/0004-dev-prod-database.md) 참고.

### 테이블 구조 바꾸기 (Alembic)

```powershell
cd server
# 1) server/src/server/models/ 에 모델 작성 후 models/__init__.py 에 import 추가
# 2) 변경 내용으로 마이그레이션 파일 자동 생성
uv run alembic revision --autogenerate -m "add todo table"
# 3) 생성된 migrations/versions/*.py 내용을 눈으로 확인한 뒤 적용
uv run alembic upgrade head
# 4) 마이그레이션 파일도 같이 커밋 → 다른 PC는 pull 후 setup.ps1 (또는 upgrade head)
```

| 명령 | 의미 |
|---|---|
| `uv run alembic current` | 지금 DB가 어느 버전인지 |
| `uv run alembic history` | 마이그레이션 목록 |
| `uv run alembic downgrade -1` | 한 단계 되돌리기 |

### 개발 DB 완전히 초기화

```powershell
docker compose down -v        # -v: 데이터 볼륨까지 삭제
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```

## 포트 정리

| 서비스 | 주소 | 바꾸는 곳 |
|---|---|---|
| PostgreSQL | `localhost:5442` | 루트 `.env`의 `DB_PORT` + `server/.env`의 `DATABASE_URL` 포트 |
| API (FastAPI) | `http://localhost:8000` (문서: `/docs`) | 실행 명령의 `--port` |
| Web (Next.js) | `http://localhost:3100` | `web/package.json`의 dev/start 스크립트 |

기본값을 피한 이유 (최초 개발 PC 기준): 5432는 로컬 PostgreSQL 18 서비스, 5433은 다른 프로젝트 컨테이너가 사용 중이고,
3000은 Windows 예약 포트 대역이다. 다른 PC에서는 사정이 다를 수 있으니 충돌하면 위 표의 위치에서 바꾼다.

## 수동 실행 (스크립트 없이)

```powershell
docker compose up -d
cd server; uv sync; uv run alembic upgrade head; uv run uvicorn server.main:app --reload
cd web; npm install; npm run dev        # 새 터미널
```

브라우저에서 `http://localhost:3100` 접속 → "백엔드 연결됨 · DB connected"가 보이면 정상.

## 검사

```powershell
cd server; uv run ruff check .; uv run ruff format --check .; uv run pytest
cd web; npm run lint; npm run build
```

## 자주 나는 문제

| 증상 | 원인 | 해결 |
|---|---|---|
| `uv` 명령을 찾을 수 없음 | 설치 직후 PATH 미반영 | 터미널을 새로 열거나 `$env:Path = "$HOME\.local\bin;$env:Path"` |
| `password authentication failed for user "board"` | 다른 PostgreSQL이 같은 포트를 사용 중 | `docker ps -a`, `Get-Service *postgres*`로 확인 후 `DB_PORT` 변경 |
| `port is already allocated` | 다른 컨테이너가 같은 포트 사용 | 위와 동일 |
| `listen EACCES: permission denied 0.0.0.0:3000` | Windows(Hyper-V/WSL)가 포트 대역을 예약 | `netsh int ipv4 show excludedportrange protocol=tcp`로 확인 후 범위 밖 포트 사용 (재부팅 시 대역이 바뀔 수 있음) |
| alembic 실행 시 `UnicodeDecodeError: 'cp949'` | `alembic.ini`에 한글이 들어감 (Windows는 cp949로 읽음) | `alembic.ini`는 영어(ASCII)로만 작성 |
| `.ps1` 실행 시 한글이 깨지거나 문법 오류 | Windows PowerShell 5.1은 BOM 없는 UTF-8을 ANSI로 읽음 | `.ps1` 파일은 **UTF-8 with BOM**으로 저장 |
| 웹에 "백엔드에 연결할 수 없습니다" | server 미실행 또는 `web/.env.local`의 `API_URL` 불일치 | server 실행 확인 |
