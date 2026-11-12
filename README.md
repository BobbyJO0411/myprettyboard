# myprettyboard

나만의 개인 대시보드. 할 일 · 일정 · 블로그 템플릿/자동 발행 · 자동화 스크립트 · 원격 PC 제어를
**웹과 모바일**에서 한곳에 모아 관리한다.

## 구조

```
myprettyboard/
├─ server/   FastAPI 백엔드 (Python, uv) — API · 스케줄러 · 자동화 · 원격 PC 연결의 중심
├─ web/      Next.js 웹 대시보드 (TypeScript, Tailwind)
├─ docs/     기록: 작업 일지 · 결정 기록 · 프롬프트 · 실행 가이드
├─ scripts/  setup.ps1(새 PC 세팅) · dev.ps1(개발 서버 실행)
└─ docker-compose.yml   개발용 PostgreSQL
```

예정: `mobile/` (Expo), `agent/` (원격 PC용 Python 프로그램)

## 빠른 시작 (어느 PC에서든)

사전 준비: Git, uv, Node.js 22+, Docker Desktop (실행 중)

```powershell
git clone https://github.com/BobbyJO0411/myprettyboard.git
cd myprettyboard
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # 최초 1회, git pull 후에도
powershell -ExecutionPolicy Bypass -File scripts\dev.ps1     # API :8000, 웹 :3100
```

자세한 내용은 [docs/runbook.md](docs/runbook.md), 폴더 구조는 [docs/structure.md](docs/structure.md), 기록 체계는 [docs/README.md](docs/README.md) 참고.
