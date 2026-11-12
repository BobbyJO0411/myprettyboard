# 프롬프트 모음

다시 쓸 수 있는 프롬프트를 모아 둔다. `{{ }}` 부분을 바꿔서 그대로 붙여 넣으면 된다.

## 개발용 (AI에게 작업을 시킬 때)

| 파일 | 용도 |
|---|---|
| [dev/session-start.md](dev/session-start.md) | 새 작업 세션 시작: 기록을 읽고 이어서 작업 |
| [dev/add-feature.md](dev/add-feature.md) | 새 기능 추가 (백엔드 API + 웹 화면 + 기록) |
| [dev/troubleshoot.md](dev/troubleshoot.md) | 오류 해결 + 해결 과정 기록 |
| [dev/session-wrapup.md](dev/session-wrapup.md) | 세션 마무리: devlog·ADR·runbook 정리 |

## 서비스용 (앱 안에서 쓸 프롬프트)

| 파일 | 용도 | 상태 |
|---|---|---|
| [app/blog-post-from-template.md](app/blog-post-from-template.md) | 템플릿 기반 블로그 글 생성 | 초안 (기능 구현 시 확정) |

## 방향을 정한 실제 질문들

비슷한 결정을 다시 할 때 참고. 결론은 [decisions/](../decisions/)에 있다.

1. "블로그 자동 작성 템플릿 저장, 블로그 연동, 스케줄러, 할 일, 원격 PC 제어까지 할 건데 뭐가 좋을까?" → 서버 앱 구조
2. "백엔드는 필요 없니? 요즘 추세가 백엔드 안 쓰니?" → 필요함, BaaS와의 차이
3. "모바일 앱에서도 쓰고 자동화도 시킬 텐데?" → 백엔드 분리 확정
4. "자동화 스크립트가 핵심일 수 있는데 FastAPI로 갈까?" → FastAPI 채택
5. "uv가 낫니? uvicorn이랑 차이가 있니?" → uv(패키지 관리) + uvicorn(웹 서버)
6. "셋팅하면서 흐름과 프롬프트를 프로젝트에 기록해줘" → 이 docs 체계
7. "보통은 backend/ frontend/로 나누지 않아? 요즘 어떻게 쓰니?" → `server/` + `web/` 유지 (ADR 0001 폴더 이름 절)
