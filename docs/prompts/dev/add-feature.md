# 새 기능 추가

```
{{기능 이름}} 기능을 추가하자.

요구사항:
- {{요구사항 1}}
- {{요구사항 2}}

진행 방식:
1. server: SQLAlchemy 모델 → Alembic 마이그레이션 → Pydantic 스키마 → API 라우터 → pytest 테스트
2. web: 화면 추가 (데이터는 server API로만 접근)
3. ruff / pytest / npm run lint / npm run build 통과를 확인하고, 실제로 실행해서 동작 확인
4. 기록: 오늘 devlog에 추가, 구조적 결정이 있었다면 ADR 작성, 실행 방법이 바뀌면 runbook 갱신

구현 전에 설계(모델 필드, API 경로)를 먼저 보여주고 내 확인을 받아줘.
```
