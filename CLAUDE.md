# myprettyboard — AI 작업 규칙

개인 대시보드: 할 일 · 일정 · 블로그 템플릿/자동 발행 · 자동화 · 원격 PC 제어. 웹 + (예정) 모바일.
구조와 이유는 `docs/decisions/` 참고. 사용자와는 한국어로 소통한다.

## 구조

- `server/` — FastAPI (Python 3.13, uv). 패키지는 `src/server/`. 모든 비즈니스 로직은 여기에 둔다.
- `web/` — Next.js 16 (App Router, TS, Tailwind 4). 화면만 담당하고 데이터는 server API로만 접근.
  **Next.js 코드를 쓰기 전에 `web/AGENTS.md` 지시대로 `web/node_modules/next/dist/docs/`를 확인할 것.**
- `docker-compose.yml` — 개발용 PostgreSQL (localhost:5442)

## 명령어

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # 환경 세팅 (여러 번 실행해도 안전)
powershell -ExecutionPolicy Bypass -File scripts\dev.ps1     # DB + API + 웹 실행
docker compose up -d
cd server; uv run uvicorn server.main:app --reload   # :8000
cd server; uv run alembic revision --autogenerate -m "..."; uv run alembic upgrade head
cd server; uv run ruff check .; uv run ruff format .; uv run pytest
cd web; npm run dev                                   # :3100
cd web; npm run lint; npm run build
```

- Python 패키지는 `uv add` / `uv add --dev`로만 추가한다 (pip 사용 금지).
- 포트: DB 5442, API 8000, Web 3100. 3000·5432·5433은 최초 개발 PC에서 쓸 수 없다 (이유는 `docs/runbook.md`).
- 여러 PC에서 개발한다. DB 테이블 변경은 **반드시 Alembic 마이그레이션 파일**로 (DB를 손으로 고치지 말 것). ADR 0004 참고.
- 모델은 `server/src/server/models/`에 두고 `models/__init__.py`에서 import 한다.
- Windows 인코딩 주의: `alembic.ini`는 ASCII만, `.ps1`은 UTF-8 with BOM.

## 기록 규칙 (중요)

사용자는 **세팅 흐름과 프롬프트가 프로젝트에 남는 것**을 중요하게 여긴다. 작업할 때마다:

1. **devlog**: `docs/devlog/YYYY-MM-DD-주제.md`에 목표, 실제로 실행한 명령어(복사해서 재실행 가능하게),
   결과, 실패한 시도와 원인·해결, 다음 할 일을 적는다. 같은 날 작업은 같은 파일에 이어 쓴다.
2. **decisions**: 기술·구조를 선택하면 `docs/decisions/NNNN-주제.md` ADR을 쓰고 `decisions/README.md` 목록을 갱신한다.
3. **runbook**: 실행 방법·포트·환경이 바뀌거나 새 오류를 해결하면 `docs/runbook.md`를 갱신한다.
4. **prompts**: 다시 쓸 만한 프롬프트(개발용 또는 앱 기능용)는 `docs/prompts/`에 추가하고 목록을 갱신한다.
5. **structure**: 새 폴더나 주요 파일이 생기면 `docs/structure.md` 지도를 갱신한다.

커밋은 사용자가 요청할 때만 한다.
