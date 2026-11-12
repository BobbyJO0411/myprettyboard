# 디렉토리 구조 안내

"어떤 파일이 어디에 있고, 무슨 일을 하는지" 정리한 지도다. 폴더 이름을 이렇게 정한 이유는 [ADR 0001](decisions/0001-architecture.md) 참고.
새 폴더나 주요 파일이 생기면 이 문서도 같이 고친다.

## 먼저 알아둘 것 두 가지

1. **FastAPI는 정해진 폴더 구조가 없다.** Django·Spring처럼 "컨트롤러는 여기, 모델은 여기"를 프레임워크가 강제하지 않는다.
   파일 하나로도 돌아가므로, 아래 폴더 구분은 우리가 정한 것이다.
2. **`server`가 두 번 나온다.** `server/src/server/`에서 앞의 `server/`는 프로젝트 폴더(설정·도구 파일),
   뒤의 `server/`는 Python 패키지 이름이다. **진짜 FastAPI 코드는 `server/src/server/` 안에만 있다.**

## 1. 전체 지도

```
myprettyboard/
│
├── server/                         ◀ 백엔드 "프로젝트" 폴더 (설정·도구 파일들)
│   ├── pyproject.toml              의존성 목록 (= package.json 같은 것)
│   ├── uv.lock                     의존성 정확한 버전 고정 (= package-lock.json)
│   ├── .python-version             Python 3.13 사용 표시 (uv가 읽음)
│   ├── .env / .env.example         DB 주소 등 환경변수 (.env는 git에 안 올라감)
│   ├── alembic.ini                 Alembic(마이그레이션 도구) 설정. ASCII만 쓸 것
│   │
│   ├── src/server/                 ◀◀ 실제 FastAPI 코드는 전부 여기 ★
│   │   ├── main.py                 앱 시작점
│   │   ├── config.py               설정값
│   │   ├── db.py                   DB 연결
│   │   ├── api/                    URL 엔드포인트
│   │   │   └── health.py
│   │   └── models/                 DB 테이블 정의 (아직 비어 있음)
│   │
│   ├── migrations/                 DB 테이블 변경 이력
│   │   ├── env.py                  Alembic이 우리 모델·DB를 찾는 연결 코드
│   │   └── versions/               변경 1건 = 파일 1개 (지금은 빈 baseline 1개)
│   │
│   └── tests/                      pytest 테스트
│       └── test_health.py
│
├── web/                            ◀ Next.js
│   ├── src/app/                    화면(페이지). 폴더 = URL
│   │   ├── layout.tsx              모든 페이지 공통 틀
│   │   ├── page.tsx                "/" 첫 화면
│   │   └── globals.css             Tailwind 스타일
│   ├── src/lib/api.ts              백엔드 호출 함수
│   ├── public/                     이미지 등 정적 파일 (지금은 기본 svg)
│   ├── package.json, next.config.ts, tsconfig.json, eslint.config.mjs
│   ├── AGENTS.md                   AI용 안내: Next.js 코드 쓰기 전에 문서 확인
│   └── .env.local                  API_URL=http://localhost:8000
│
├── docker-compose.yml              개발용 PostgreSQL 컨테이너 (localhost:5442)
├── scripts/
│   ├── setup.ps1                   새 PC 세팅 (여러 번 실행해도 안전)
│   └── dev.ps1                     DB + API + 웹 한 번에 실행
├── docs/                           기록 (devlog, decisions, prompts, runbook, learning, 이 문서)
├── .env.example                    루트 환경변수 (DB_PORT 등)
├── CLAUDE.md                       AI 작업 규칙
└── README.md
```

### 왜 `src/`를 한 번 더 감쌌나

- 설정 파일(`pyproject.toml`, `alembic.ini` 등)과 실제 코드를 분리한다.
- 테스트가 "폴더에 있는 파일"이 아니라 "설치된 `server` 패키지"를 import하게 만들어서, 내 PC에서만 import가 되는 실수를 막는다.
- uv가 프로젝트를 만들 때 기본으로 쓰는 구조다.

그래서 코드에서는 항상 `from server.db import get_db`처럼 **`server.`으로 시작해서** import한다.

## 2. FastAPI 코드 파일별 역할

| 파일 | 역할 | 비유 |
|---|---|---|
| `main.py` | `app = FastAPI()` 생성, CORS 허용, 라우터 등록. uvicorn이 실행하는 대상 (`server.main:app`) | 건물 정문 |
| `config.py` | `.env`를 읽어 `settings.database_url` 같은 설정값을 만든다 | 설정표 |
| `db.py` | DB 엔진 생성, 모든 모델의 부모 `Base`, 요청마다 DB 세션을 주는 `get_db()` | DB로 가는 통로 |
| `api/*.py` | `@router.get("/health")`처럼 **URL과 처리 함수를 연결**. 기능마다 파일 하나 | 창구 |
| `models/*.py` | `class Todo(Base)`처럼 **DB 테이블을 Python 클래스로** 정의. `models/__init__.py`에서 import해야 Alembic이 인식 | 테이블 설계도 |

## 3. 요청 하나가 흘러가는 길

웹 첫 화면에 "백엔드 연결됨 · DB connected"가 뜨는 과정:

```
[브라우저] http://localhost:3100
   │
   ▼
web/src/app/page.tsx          ServerStatus 컴포넌트가 실행됨
   │  apiGet("/health/db")
   ▼
web/src/lib/api.ts            fetch("http://localhost:8000/health/db")
   │  ─────────── HTTP ───────────
   ▼
server/src/server/main.py     app이 요청을 받음 → 라우터에 전달
   │                          (CORS는 브라우저가 직접 부를 때만 검사. 이 요청은 Next.js 서버가 보내므로 해당 없음)
   │
   ▼
server/src/server/api/health.py   health_db() 실행
   │  db: DbSession  ← FastAPI가 자동으로 get_db()를 호출해 넣어줌 (의존성 주입)
   ▼
server/src/server/db.py       SessionLocal() → engine → config.py의 DB 주소
   │
   ▼
docker-compose.yml의 PostgreSQL (localhost:5442)   SELECT 1
   │
   ▼
{"status":"ok","db":"connected"}  → 웹 화면에 표시
```

## 4. DB 관련 파일 3종

| 위치 | 하는 일 |
|---|---|
| `docker-compose.yml` | **DB 서버 자체**를 띄운다 (PostgreSQL 프로그램) |
| `server/src/server/models/` | **테이블이 어떻게 생겨야 하는지** Python으로 적는다 |
| `server/migrations/versions/` | 모델과 실제 DB의 **차이를 반영하는 변경 스크립트**. Alembic이 자동 생성 |

흐름: 모델 작성 → `uv run alembic revision --autogenerate -m "..."`로 변경 파일 생성 → 내용 확인 → `uv run alembic upgrade head`로 실제 DB에 반영 → 마이그레이션 파일 커밋.
자세한 절차는 [runbook](runbook.md#테이블-구조-바꾸기-alembic).

## 5. 앞으로 기능이 추가되면 들어갈 곳 (예정)

할 일(Todo) 기능을 예로 들면:

```
server/src/server/
├── models/todo.py       DB 테이블 (SQLAlchemy)
├── schemas/todo.py      API 입출력 형식 (Pydantic)
├── services/todo.py     실제 로직 (조회·생성·수정). 로직이 커지면 분리
├── api/todos.py         URL: GET/POST /todos
└── main.py              app.include_router(todos.router) 한 줄 추가

web/src/app/todos/page.tsx   → /todos 화면
```

| 계획된 기능 | 들어갈 곳 |
|---|---|
| 스케줄러 | `server/src/server/scheduler/` |
| 블로그 발행 | `server/src/server/integrations/blog/` |
| 원격 PC 연결 | `server/src/server/api/agents.py` (WebSocket) |
| 원격 PC 프로그램 | 루트 `agent/` |
| 모바일 앱 | 루트 `mobile/` (Expo) |

## 6. 주의점

- `server/src/server/config.py`의 `env_file=".env"`는 **명령을 실행한 위치 기준**이다. 그래서 항상 `cd server` 후 실행한다.
- `web/src/lib/api.ts`의 `API_URL`은 `NEXT_PUBLIC_` 접두사가 없어서 **서버 컴포넌트에서만** 읽힌다.
