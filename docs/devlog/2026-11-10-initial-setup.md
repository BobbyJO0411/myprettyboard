# 2026-11-10 · 프로젝트 초기 세팅

## 목표

스택을 정하고, **백엔드(FastAPI) → DB(PostgreSQL) → 웹(Next.js)** 이 서로 연결되는 최소 뼈대를 만든다.

## 1. 스택 결정 (대화 요약)

| 질문 | 결론 | 기록 |
|---|---|---|
| 개인 페이지 스택? | 기능(스케줄러·자동화·원격 PC·모바일)을 보니 단순 페이지가 아니라 **개인용 서버 앱** | [ADR 0001](../decisions/0001-architecture.md) |
| 백엔드가 필요한가? | 필요. 스케줄러·자동화·원격 연결은 항상 켜진 서버가 있어야 함. "백엔드 없이"는 남의 백엔드(BaaS)를 빌려 쓴다는 뜻 | ADR 0001 |
| 모바일에서도 쓰면? | 웹·모바일이 같은 API를 써야 하니 **백엔드 분리** 확정 | ADR 0001 |
| TS vs Python? | 자동화가 핵심이 될 수 있어 **FastAPI** | [ADR 0002](../decisions/0002-backend-fastapi.md) |
| uv vs pip+venv, uvicorn과 차이? | uv(패키지 관리) + uvicorn(웹 서버) 함께 사용 | [ADR 0003](../decisions/0003-python-tooling-uv.md) |

## 2. 환경 확인

```powershell
# 결과: Python 3.13.0, Node 22.21.1, npm 10.9.4, Docker 29.1.3, Git 2.44 / uv 없음
uv --version; python --version; node -v; docker --version; git --version
```

## 3. uv 설치

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
# → uv 0.13.7, %USERPROFILE%\.local\bin 에 설치. 새 터미널부터 PATH 적용됨
```

## 4. 백엔드 생성

```powershell
git init -b main
uv init --app --python 3.13 --vcs none server   # src/server/ 패키지 구조로 생성됨
cd server
uv add "fastapi[standard]" "sqlalchemy>=2" alembic "psycopg[binary]" pydantic-settings
uv add --dev ruff pytest
```

작성한 파일:

| 파일 | 역할 |
|---|---|
| `server/src/server/main.py` | FastAPI 앱, CORS 설정, 라우터 등록 |
| `server/src/server/config.py` | 설정 (pydantic-settings, `server/.env`에서 읽음) |
| `server/src/server/db.py` | SQLAlchemy 엔진, 세션, `Base`, `get_db` 의존성 |
| `server/src/server/api/health.py` | `GET /health`, `GET /health/db` |
| `server/tests/test_health.py` | 첫 테스트 |
| `server/pyproject.toml` | ruff·pytest 설정 추가 |

## 5. DB (Docker)

`docker-compose.yml`에 `postgres:17` 컨테이너(`myprettyboard-db`)를 정의하고 `docker compose up -d`로 실행.

### 문제 1: 포트 충돌 (두 번)

- `5432` → `password authentication failed`. 에러 메시지가 한글로 나와서 컨테이너가 아님을 의심했고,
  `Get-Service *postgres*`로 확인해 보니 **PC에 설치된 PostgreSQL 18 서비스**가 5432를 쓰고 있었다.
  다른 용도일 수 있어 건드리지 않음.
- `5433` → `port is already allocated`. `docker ps -a`로 확인해 보니 **다른 프로젝트 컨테이너(branvip-postgres)** 가 사용 중.
- **해결: 5442 포트 사용.** (`docker-compose.yml`, `server/.env`, `config.py` 기본값 변경)

```powershell
docker ps -a --format "{{.Names}}`t{{.Ports}}"   # 포트를 쓰는 컨테이너 찾기
Get-Service *postgres*                           # 로컬에 설치된 PostgreSQL 찾기
```

### 문제 2: ruff B008 경고

`def f(db: Session = Depends(get_db))` 형태가 경고 대상. FastAPI 권장 방식인 `Annotated`로 변경:
`DbSession = Annotated[Session, Depends(get_db)]`

검증: `uv run ruff check .` 통과, `uv run pytest` 1 passed, `GET /health/db` → `{"status":"ok","db":"connected"}`

## 6. 웹 생성

```powershell
npx --yes create-next-app@latest web --ts --tailwind --eslint --app --src-dir --use-npm --import-alias "@/*" --turbopack --disable-git --yes
```

- Next.js **16.4.6**, React 19.3, Tailwind 4.3. `cacheComponents`가 기본으로 켜져 있음.
- `web/AGENTS.md`: Next.js가 자동 생성하는 AI용 안내. "학습 데이터와 다른 버전이니 `node_modules/next/dist/docs/`를 먼저 읽어라"는 내용이며 그대로 둔다.
- `web/src/lib/api.ts`: 백엔드 호출 헬퍼 (`API_URL`, 기본 `http://localhost:8000`)
- `web/src/app/page.tsx`: 첫 화면에서 `/health/db`를 호출해 연결 상태 표시.
  cacheComponents 환경에서는 캐시하지 않는 fetch를 `<Suspense>`로 감싸야 함 (번들 문서 `01-app/01-getting-started/06-fetching-data.md`)

### 문제 3: lint `react-hooks/error-boundaries`

try/catch 안에서 JSX를 반환하면 오류. → 데이터 조회(`getDbStatus`)만 try/catch로 감싸고 JSX는 바깥에서 반환.

### 문제 4: `listen EACCES: permission denied 0.0.0.0:3000`

```powershell
netsh int ipv4 show excludedportrange protocol=tcp   # → 2956~3055 대역이 예약되어 있었음
```

Windows(Hyper-V/WSL)가 동적으로 예약한 포트 대역. **해결: 웹 포트를 3100으로** (`package.json`의 dev/start 스크립트, 백엔드 CORS 허용 주소 변경).
재부팅하면 예약 대역이 바뀔 수 있으니 같은 오류가 나면 위 명령으로 다시 확인.

검증: server + web 동시 실행 → `http://localhost:3100`에 "백엔드 연결됨 · DB connected" 표시 확인. `npm run lint`, `npm run build` 통과.

## 7. 기록 체계 구축

`docs/` 아래에 devlog / decisions / prompts / runbook, 루트에 `CLAUDE.md`(AI 작업 규칙) 작성.
설명은 [docs/README.md](../README.md) 참고.

## 8. 여러 PC에서 개발할 수 있게 인프라 구성

질문: "다른 컴퓨터에서도 이어가려면 git이랑 DB가 연동돼야 할 것 같은데?" → 그때까지는 이 PC에만 있는 상태였다.
"DB 하나를 같이 쓰는 게 낫지 않나?"라는 의문도 정리해서 **개발 DB는 PC마다, 구조는 git으로 공유, 운영 DB는 한 곳**으로 결정
([ADR 0004](../decisions/0004-dev-prod-database.md)).

### 8-1. DB 포트를 PC마다 바꿀 수 있게

`docker-compose.yml`의 포트를 `"${DB_PORT:-5442}:5432"`로 바꾸고, 루트에 `.env.example`(`DB_PORT=5442`)을 추가.
docker compose는 루트 `.env`를 자동으로 읽는다.

### 8-2. Alembic (테이블 구조 = 마이그레이션 파일로 git 공유)

```powershell
cd server
uv run alembic init migrations
```

- `alembic.ini`: `file_template` 주석 해제 (파일명을 `2026_11_10_1617-<rev>_<slug>.py`처럼 날짜순으로)
- `migrations/env.py`: DB 주소를 `server/.env`(`settings.database_url`)에서 읽고, `target_metadata = Base.metadata` 설정
- `src/server/models/__init__.py`: 모델 모음. 새 모델은 여기서 import 해야 autogenerate가 인식함

```powershell
uv run alembic revision -m "baseline"    # 빈 기준점 마이그레이션
uv run alembic upgrade head
uv run alembic current                   # → 1bb13473686f (head)
```

#### 문제 5: `UnicodeDecodeError: 'cp949' codec can't decode byte 0xec`

`alembic.ini`에 한글 주석을 넣었더니 Windows가 cp949로 읽다가 실패. → **ini 파일은 영어(ASCII)로만** 작성.

### 8-3. 원클릭 스크립트

| 파일 | 역할 |
|---|---|
| `scripts/setup.ps1` | 도구 확인 → `.env` 복사 → DB 실행 → `uv sync` → `alembic upgrade head` → `npm install`. 여러 번 실행해도 안전 |
| `scripts/dev.ps1` | DB 실행 후 백엔드·웹을 각각 새 창에서 실행 |

#### 문제 6: PowerShell 5.1과 한글

Windows PowerShell 5.1은 BOM이 없는 UTF-8 `.ps1`을 ANSI(cp949)로 읽어서 한글 메시지가 깨진다. → **`.ps1`은 UTF-8 with BOM으로 저장**.

```powershell
$t = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($path, $t, (New-Object Text.UTF8Encoding $true))   # BOM 붙이기
```

검증: `powershell -ExecutionPolicy Bypass -File scripts\setup.ps1` 6단계 모두 통과.

### 8-4. GitHub 비공개 저장소에 올리기

```powershell
git add -A
git commit -m "..."
gh repo create myprettyboard --private --source . --remote origin --push
# → "Name already exists on this account" : 2024-01에 만들어 둔 같은 이름의 빈 비공개 저장소가 있었음
gh repo view BobbyJO0411/myprettyboard --json isEmpty,visibility   # 비어 있음 + PRIVATE 확인 후 그대로 사용
git remote add origin https://github.com/BobbyJO0411/myprettyboard.git
git push -u origin main
```

- 저장소: https://github.com/BobbyJO0411/myprettyboard (비공개)
- 커밋 전 확인: `git diff --cached --name-only | grep -i .env` → `.env.example` 3개만 올라가는지 확인.
  Next.js가 만든 `web/.gitignore`가 `.env*`를 전부 무시해서 `web/.env.example`이 빠졌었음 → `!.env.example` 예외 추가.
- `.gitattributes` 추가: 줄바꿈 통일 (`* text=auto`, `.ps1`은 CRLF).

다른 PC에서는 `docs/runbook.md`의 "새 PC에서 시작하기"를 따르면 된다.

## 다음 할 일

- [ ] 블로그 플랫폼 결정 (WordPress / 티스토리 / 네이버 / 기타) → 자동 발행 방식 결정
- [ ] 서버를 돌릴 곳 결정 (집 PC / 미니PC / VPS) → 운영 DB 구성
- [x] Alembic 초기화
- [ ] 첫 모델 (할 일 `Todo`) + 시드 스크립트
- [ ] 할 일 CRUD API + 웹 화면
- [ ] 인증 (1인용, 토큰 기반)
- [ ] OpenAPI → TS 클라이언트 자동 생성 설정
- [x] 첫 커밋 + GitHub 비공개 저장소

## 9. 디렉토리 구조 점검: 폴더 이름

질문: "보통은 backend/ frontend/로 나누지 않아? 이거랑 무슨 차이니? 요즘 어떻게 쓰니?"

- 결론: 구조는 같고 이름만 다르다. 클라이언트가 여러 개(web·mobile·agent)이고 백엔드가 Python이라 `server/` + `web/`를 유지한다.
- 폴더 이름을 정한 근거가 ADR에 빠져 있었음 → [ADR 0001](../decisions/0001-architecture.md)에 "폴더 이름" 절 추가.
- 코드 변경 없음.

점검하면서 발견한 주의점 (지금은 문제 없음):

- `server/src/server/config.py`의 `env_file=".env"`는 **현재 디렉토리 기준**이다. `server/` 밖에서 실행하면 `server/.env`를 못 읽고 기본값을 쓴다. 배포(Docker) 시 확인할 것.
- `web/src/lib/api.ts`의 `process.env.API_URL`은 `NEXT_PUBLIC_` 접두사가 없어서 **서버 컴포넌트에서만** 읽힌다. 클라이언트 컴포넌트에서 쓰려면 별도 처리가 필요하다.

## 10. 디렉토리 구조 안내 문서

질문: "FastAPI 구조가 눈에 안 보이고, 디렉토리별로 뭐가 뭔지 모르겠어."

- [`docs/structure.md`](../structure.md) 추가: 전체 지도, FastAPI 파일별 역할, 요청 흐름(웹 → API → DB), DB 관련 파일 3종, 앞으로 기능이 들어갈 곳.
- `docs/README.md` 표와 루트 `README.md`에 링크 추가.

## 11. 학습 로드맵 시작

- 목표: 개발 실력 키우기 + 내 전용 홈페이지 + 나중에 로그인·멀티테넌트 + 지식 저장소.
- [`docs/learning/`](../learning/README.md) 추가: 0~8단계 로드맵, 개념 사전, [0단계 둘러보기](../learning/00-tour.md).
- [요청 흐름 자세히 보기](../learning/00-flow.md) 추가: 브라우저 → Next.js → FastAPI → DB 왕복을 11칸으로, "켤 때 한 번 vs 요청마다", 실패 흐름.

### 0단계 중 문제: `scripts\dev.ps1`을 실행해도 API·웹 접속이 안 됨 (원인 확인 중)

점검 결과 (Claude가 직접 실행):

```powershell
docker ps --filter name=myprettyboard   # DB는 Up (healthy)
netstat -ano | findstr ":8000 :3100"    # 둘 다 LISTENING 없음 → 서버가 안 떠 있었음
cd server; uv run uvicorn server.main:app --reload   # 단독 실행하면 정상, /health/db → connected
```

- 명령 자체는 정상이다. dev.ps1을 실행한 위치, 터미널 종류, 새 창의 에러 메시지를 사용자에게 확인하는 중.
- 점검 중 겪은 함정: 테스트로 띄운 uvicorn이 8000번을 잡고 있는 상태에서 dev.ps1을 실행하면,
  새 백엔드 창의 uvicorn은 포트 충돌로 바로 종료된다 (창은 `-NoExit`라 열린 채 남음).

## 2026-11-12 — 레포 공개 + 기록 초기화 ("새 마음으로")

- 목표: GitHub 레포를 공개로 하고, 지금까지의 커밋 기록을 지운 뒤 커밋 1개로 새로 시작.
- 공개 전 비밀 정보 점검: 히스토리 전체에서 password/secret/token/api key 패턴 검색 → 없음.
  (`docker-compose.yml`의 `POSTGRES_PASSWORD: board`는 로컬 개발용이라 공개해도 무방)
- 실행한 명령어:

```bash
# 1) 비밀 정보 점검
git grep -nIiE "(password|secret|api[_-]?key|token)[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9_\-]{8,}" $(git rev-list --all)
# 2) 기존 기록 백업 (임시 폴더)
git bundle create <임시폴더>/myprettyboard-old-history.bundle --all
# 3) 기록 없는 새 브랜치로 커밋 1개 만들기
git checkout --orphan fresh-main; git add -A; git commit -m "chore: initial commit ..."
git branch -D main; git branch -m main
# 4) 레포 삭제 권한 받기 (브라우저 인증 필요 -> 사용자가 직접 실행)
gh auth refresh -h github.com -s delete_repo
# 5) 기존 레포 삭제 후 공개 레포로 새로 만들고 push
gh repo delete BobbyJO0411/myprettyboard --yes
gh repo create BobbyJO0411/myprettyboard --public
git push -u origin main
```

- 실패/주의: `gh repo delete`는 토큰에 `delete_repo` 권한이 없으면 실패한다 → 4번으로 해결.
- 주의: 공개 레포라 누구나 볼 수 있다. `.env` 등 비밀 값은 절대 커밋하지 않는다 (`.gitignore`에 등록됨).
