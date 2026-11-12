# 0단계: 지금 있는 앱 둘러보기

코드를 한 줄도 안 쓰고, 이미 만들어진 것이 **어떻게 움직이는지** 눈으로 확인한다.

## 개념 1. 서버

**계속 켜져서 요청이 오기를 기다리는 프로그램.** 식당 주방처럼 손님(브라우저)이 주문(요청)하면 요리(응답)를 내준다.

```
포트 3100  web (Next.js)     ← 사람이 보는 화면을 만들어 줌
포트 8000  server (FastAPI)  ← 데이터를 주고받는 창구 (API)
포트 5442  PostgreSQL        ← 데이터를 저장하는 창고
```

**포트**는 한 건물(내 PC) 안의 문 번호다.

## 개념 2. HTTP 요청과 응답

```
요청 (Request)                       응답 (Response)
GET /health                          200 OK
 ↑    ↑                               ↑
동사  주소                           상태코드
                                     {"status": "ok"}   ← 본문 (JSON)
```

- 메서드: `GET` 조회, `POST` 생성, `PUT/PATCH` 수정, `DELETE` 삭제
- 상태코드: `200` 성공, `404` 없음, `422` 입력 잘못됨, `500` 서버 에러
- 브라우저 주소창에 입력하는 것 = GET 요청

## 직접 해보기

1. 켜기 (**프로젝트 루트에서**, PowerShell): `powershell -ExecutionPolicy Bypass -File scripts\dev.ps1`
   - 백엔드·웹이 **새 PowerShell 창 두 개**로 뜬다. 끌 때는 그 창을 닫는다.
2. 브라우저로 API 부르기: `http://localhost:8000/health`, `http://localhost:8000/health/db`
3. **FastAPI 자동 문서**: `http://localhost:8000/docs` → `/health/db` → Try it out → Execute
   - 우리가 만든 페이지가 아니다. FastAPI가 코드를 읽고 자동 생성한다. 원본: `/openapi.json`
4. 웹: `http://localhost:3100` → "백엔드 연결됨 · DB connected"

## 일부러 망가뜨려 보기

- **실험 A**: `docker compose stop db` → `/health`, `/health/db`, 웹을 각각 새로고침. 어디가 왜 깨지나? → `docker compose start db`
- **실험 B**: `server/src/server/api/health.py`의 `return {"status": "ok"}`를 `{"status": "ok", "message": "안녕"}`으로 바꾸고 저장 → 서버 재시작 없이 반영됨 (`--reload` 덕분)
- **실험 C**: `cd server; uv run pytest` → 실험 B 때문에 테스트 실패. 테스트 = 무심코 바꾼 걸 잡아주는 안전망. 원래대로 되돌리고 다시 통과 확인.

## 퀴즈

1. DB를 꺼도 `/health`는 멀쩡했나? 이유를 `health.py`에서 찾아보기.
2. 웹에서 F12 → Network 탭. `localhost:8000/health/db` 요청이 보이나? 안 보이면 누가 보낸 걸까? (힌트: 서버 컴포넌트)

## 내 기록

<!-- 실험 결과, 퀴즈 답, 막혔던 점을 여기에 적는다 -->

## 정리: 요청 흐름은 4층으로 기억한다

```
① 화면 (web)      page.tsx          사용자가 보고 누르는 곳
② 창구 (API)      api/health.py     요청을 받아 일을 시키는 곳
③ 데이터 연결      db.py, models/    DB와 대화하는 곳
④ 저장소 (DB)      PostgreSQL        데이터가 쌓이는 곳
```

- 요청은 위→아래, 응답은 아래→위. 파일 이름을 외우지 말고 층으로 기억한다. (파일 단위 지도: [structure.md](../structure.md#3-요청-하나가-흘러가는-길))
- **에러가 나면 몇 층에서 막혔는지부터 찾는다.** 웹이 안 열림 → ①, "백엔드에 연결할 수 없습니다" → ①과 ② 사이, `/health`는 되는데 `/health/db`가 500 → ③과 ④ 사이.
- 새 기능도 같은 4층을 하나 더 까는 것이다. (예: Todo = `app/todos/page.tsx` → `api/todos.py` → `models/todo.py` → todo 테이블)
- 한 칸씩 자세히: [00-flow.md](00-flow.md)
- 눈으로 보기: `health_db()`에 `print("② 창구에 요청 도착!")`을 넣고 웹을 새로고침하면 백엔드 창에 찍힌다. 확인 후 지울 것.
