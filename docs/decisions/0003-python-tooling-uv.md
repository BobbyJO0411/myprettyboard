# 0003. Python 도구: uv (pip+venv 대신)

- 상태: 채택
- 날짜: 2026-11-10

## 배경

기존에는 pip + venv만 사용해 왔다. 원격 PC agent를 여러 PC에 배포할 예정이라 같은 환경을 재현하는 게 중요하다.

## 선택지

- **pip + venv**: 익숙함 / 느림, activate 깜빡하는 실수, `pip freeze` 수동 관리
- **poetry**: lock 파일 지원 / 느리고 설정이 복잡함
- **uv**: 매우 빠름, 가상환경·Python 버전·lock 자동 관리, pip 명령 호환 / 비교적 새 도구

## 결정

**uv.** 참고로 uvicorn과는 다른 도구다. uv = 패키지/프로젝트 관리자, uvicorn = FastAPI를 실행하는 웹 서버. 둘 다 쓴다.

| 하려는 일 | pip + venv | uv |
|---|---|---|
| 패키지 설치 | `pip install X` | `uv add X` |
| 개발용 패키지 | - | `uv add --dev X` |
| 환경 복원 | `pip install -r requirements.txt` | `uv sync` |
| 실행 | (activate 후) `python main.py` | `uv run main.py` |
| requirements.txt 필요 시 | - | `uv export > requirements.txt` |

## 이유와 영향

- 의존성은 `server/pyproject.toml`과 `server/uv.lock`에 기록되며 둘 다 커밋한다.
