# 요청 흐름 자세히 보기: "백엔드 연결됨 · DB connected"가 뜨기까지

[0단계](00-tour.md)의 4층 그림(화면 → 창구 → 데이터 연결 → 저장소)을 실제 코드와 함께 한 칸씩 따라간다.

## 먼저 구분할 것: "켤 때 한 번" vs "요청마다"

가장 많이 헷갈리는 부분이다. 코드에는 **서버를 켤 때 딱 한 번 실행되는 부분**과 **요청이 올 때마다 실행되는 부분**이 섞여 있다.

| 켤 때 한 번 (개점 준비) | 요청마다 (주문 처리) |
|---|---|
| `config.py`: `.env`를 읽어 `settings` 만들기 | |
| `db.py`: `engine`(DB 연결 풀) 만들기 | `get_db()`: 세션을 빌려주고 반납받기 |
| `main.py`: `app` 만들기, 미들웨어·라우터 등록 | 라우터가 URL에 맞는 함수 찾기 |
| | `health_db()` 실행, `SELECT 1` |

식당에 비유하면 왼쪽은 문 열기 전에 재료를 준비하고 메뉴판을 거는 일, 오른쪽은 손님 주문이 올 때마다 하는 일이다.
`main.py`는 요청마다 실행되는 게 아니다. 켤 때 만든 `app`이 계속 요청을 처리한다.

## 전체 왕복 지도

```
 ① 브라우저 ──GET /──▶ ② Next.js 서버(3100): page.tsx
                              │ ③ api.ts: GET /health/db
                              ▼
                       ④ uvicorn(8000) ─▶ ⑤ app: 미들웨어 → 라우터
                                                  │
                                    ⑥ 의존성 주입: get_db()가 세션을 빌려줌
                                                  ▼
                                    ⑦ health_db() → db.py의 engine
                                                  │
                                                  ▼
                                    ⑧ PostgreSQL(5442): SELECT 1
                                                  │
 ⑪ 브라우저에 표시 ◀── ⑩ page.tsx가 HTML 생성 ◀── ⑨ JSON 응답 {"db":"connected"}
```

요청은 ①→⑧ 내려가고, 응답은 ⑨→⑪ 올라온다.

---

## ① 브라우저 → Next.js 서버

주소창에 `http://localhost:3100`을 치면 브라우저가 **3100번 문(Next.js 서버)**에 `GET /` 요청을 보낸다.
Next.js는 `web/src/app/` 폴더에서 `/`에 해당하는 `page.tsx`를 찾는다. **폴더 구조 = URL**이다.

| 파일 | URL |
|---|---|
| `app/page.tsx` | `/` |
| `app/todos/page.tsx` (나중에) | `/todos` |

모든 페이지는 `app/layout.tsx`라는 공통 틀 안에 들어간다.

## ② page.tsx: 화면 그리기 시작

```tsx
export default function Home() {
  return (
    <main>
      <h1>myprettyboard</h1>
      <Suspense fallback={<p>백엔드 상태 확인 중…</p>}>
        <ServerStatus />
      </Suspense>
    </main>
  );
}
```

- **`Suspense`**: 안쪽(`ServerStatus`)이 준비될 때까지 `fallback`("확인 중…")을 먼저 보여 주고, 준비되면 갈아 끼운다. 백엔드 응답이 느려도 화면 전체가 멈추지 않는다.
- **`ServerStatus`는 `async` 서버 컴포넌트**다. 브라우저가 아니라 **Next.js 서버에서** 실행된다.
  그래서 브라우저 F12 Network 탭에는 `localhost:8000` 요청이 보이지 않는다. (0단계 퀴즈 2번의 답)

```tsx
async function ServerStatus() {
  const db = await getDbStatus();   // ③으로 내려감. 응답이 올 때까지 기다림(await)
  ...
}
```

## ③ api.ts: HTTP 요청 보내기

```ts
export const API_URL = process.env.API_URL ?? "http://localhost:8000";

export async function apiGet<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`);
  if (!res.ok) throw new Error(`API ${path} 실패: ${res.status}`);
  return res.json() as Promise<T>;
}
```

- `API_URL`은 `web/.env.local`에서 읽는다. 없으면 기본값 `http://localhost:8000`을 쓴다.
- `fetch`가 실제로 네트워크에 보내는 내용은 이런 **텍스트**다.

```
GET /health/db HTTP/1.1
Host: localhost:8000
```

HTTP는 이렇게 정해진 형식의 글자를 주고받는 약속일 뿐이다.

## ④ uvicorn: 8000번 문지기

8000번 문에서 기다리는 건 FastAPI가 아니라 **uvicorn**(웹 서버)이다.

| | 하는 일 | 비유 |
|---|---|---|
| uvicorn | HTTP 텍스트를 받아 Python이 다루기 쉬운 형태로 바꾼 뒤 `app`에 넘긴다 | 홀 직원 |
| FastAPI `app` | 받은 요청을 처리할 함수를 찾아 실행한다 | 주방 |

실행 명령 `uvicorn server.main:app`은 "`server/main.py` 안의 `app`에게 요청을 넘겨라"라는 뜻이다.
(uv는 패키지 관리자, uvicorn은 웹 서버. 이름만 비슷하고 다른 도구다.)

## ⑤ app: 미들웨어 → 라우터

```python
app = FastAPI(title=settings.app_name)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, ...)
app.include_router(health.router)
```

이 코드는 **켤 때 한 번** 실행되어 `app`을 조립해 둔다. 요청이 오면 조립된 `app`이 이 순서로 처리한다.

1. **미들웨어**: 모든 요청이 거쳐 가는 검문소. 지금은 CORS 하나뿐이다.
   CORS는 **브라우저가** 다른 주소의 서버를 부를 때만 의미가 있다. 이 요청은 Next.js 서버가 보냈으므로 그냥 통과한다.
2. **라우터**: (메서드, 주소) 짝으로 실행할 함수를 찾는다.

| 요청 | 실행되는 함수 |
|---|---|
| `GET /health` | `health()` |
| `GET /health/db` | `health_db()` |
| `GET /health/xyz` | 없음 → **404 Not Found** |
| `POST /health` | 주소는 있는데 메서드가 다름 → **405 Method Not Allowed** |

`@router.get("/health/db")`라는 데코레이터가 이 표에 한 줄을 등록하는 것이다.

## ⑥ 의존성 주입: get_db()가 세션을 빌려줌

```python
DbSession = Annotated[Session, Depends(get_db)]

@router.get("/health/db")
def health_db(db: DbSession) -> dict[str, str]:
```

FastAPI는 함수를 실행하기 전에 매개변수를 본다. `db`에 `Depends(get_db)`가 붙어 있으면
"이 함수를 실행하기 전에 `get_db()`를 먼저 호출해서, 그 결과를 `db`에 넣어 줘"라는 뜻으로 알아듣는다.
이걸 **의존성 주입(Dependency Injection)**이라고 한다. 함수가 필요한 걸 직접 만들지 않고 밖에서 넣어 받는 것이다.

```python
def get_db() -> Iterator[Session]:
    db = SessionLocal()   # 1. 세션 하나 만들기
    try:
        yield db          # 2. 빌려주기 → health_db() 실행 → 응답이 끝날 때까지 여기서 대기
    finally:
        db.close()        # 3. 끝나면 반드시 반납 (에러가 나도)
```

`yield`는 "여기서 잠깐 넘겨주고, 일이 끝나면 다음 줄부터 이어서 하겠다"는 뜻이다. 도서관 대출·반납과 같다.

**왜 이렇게 할까?**
- API가 100개여도 DB를 열고 닫는 코드는 `get_db` 한 곳에만 있다.
- 반납(`close`)을 깜빡할 수 없다.
- 테스트할 때 `get_db`만 가짜 DB로 바꿔 끼우면 된다.

## ⑦ health_db() → db.py의 engine

```python
db.execute(text("SELECT 1"))
```

이 줄에서 실제로 DB와 대화한다. 그 뒤에서는 `db.py`가 켤 때 준비해 둔 것들이 움직인다.

```python
engine = create_engine(settings.database_url, pool_pre_ping=True)   # 켤 때 한 번
SessionLocal = sessionmaker(bind=engine, autoflush=False)           # 세션 공장
```

- **engine**: DB 연결을 관리하는 본체. **연결 풀(pool)**을 갖고 있다. DB 연결은 맺는 데 시간이 걸리므로,
  한 번 맺은 연결을 버리지 않고 모아 두었다가 다음 요청에 돌려 쓴다. 전화를 매번 새로 거는 대신 열어 둔 회선을 쓰는 것과 같다.
- **`pool_pre_ping=True`**: 회선을 쓰기 전에 "여보세요?" 해서 끊긴 연결이면 새로 맺는다.
- **세션(Session)**: 요청 하나 동안의 DB 대화 단위. `execute`할 때 풀에서 연결을 빌려 쓴다.

DB 주소는 `config.py`의 `settings.database_url`에서 온다.

```
postgresql+psycopg://board:board@localhost:5442/board
──────────┬──────── ────┬────── ───────┬────── ──┬──
  DB 종류 + 드라이버   사용자:비밀번호   주소:포트   DB 이름
```

`psycopg`는 Python이 PostgreSQL과 대화할 수 있게 해 주는 **드라이버**(통역사)다.

## ⑧ Docker 안의 PostgreSQL

```yaml
ports:
  - "5442:5432"   # 내 PC의 5442번 → 컨테이너 안의 5432번
```

내 PC의 5442번 문으로 들어온 연결은 Docker 컨테이너 안 PostgreSQL의 기본 문(5432번)으로 이어진다.
`SELECT 1`은 "숫자 1을 돌려줘"라는 가장 간단한 SQL이다. 데이터를 읽는 게 목적이 아니라 **DB가 살아서 대답하는지** 확인하는 용도다.

## ⑨ 응답 올라가기: dict → JSON

```python
return {"status": "ok", "db": "connected"}
```

Python dict를 돌려주면 FastAPI가 알아서 JSON 글자로 바꾸고 상태코드 200을 붙인다. 그 뒤 `get_db`의 `finally`가 실행되어 세션을 반납한다.
uvicorn이 실제로 돌려보내는 텍스트는 이렇다.

```
HTTP/1.1 200 OK
content-type: application/json

{"status":"ok","db":"connected"}
```

## ⑩ api.ts → page.tsx

- `res.ok`: 상태코드가 200번대면 `true`
- `res.json()`: JSON 글자 → JS 객체 `{ status: "ok", db: "connected" }`
- `getDbStatus()`가 `data.db`, 즉 `"connected"`를 돌려준다.
- `ServerStatus`가 초록 글씨를 만든다.

```tsx
return <p className="text-emerald-600">백엔드 연결됨 · DB {db}</p>;
```

## ⑪ HTML → 브라우저

Next.js가 JSX를 HTML로 바꿔 브라우저에 보낸다. 브라우저는 먼저 받은 "확인 중…" 자리를 이 HTML로 갈아 끼운다(②의 Suspense).
`className="text-emerald-600"`은 Tailwind CSS로, 초록색 글씨라는 뜻이다.

---

## 실패하면 어떻게 흐를까: DB가 꺼졌을 때

```
⑧ PostgreSQL 연결 실패
⑦ db.execute()에서 에러 발생 → health_db() 중단
⑥ get_db()의 finally → 세션 반납 (에러가 나도 실행됨)
⑤ FastAPI가 에러를 500 Internal Server Error로 바꿔서 응답
③ api.ts: res.ok가 false → throw new Error(...)
② getDbStatus()의 catch → null 반환 → ServerStatus가 빨간 글씨
```

> **관찰 포인트**: 화면에는 "백엔드에 연결할 수 없습니다"라고 나오지만 실제로 백엔드는 살아 있고 **DB가 꺼진 것**이다.
> 에러 메시지가 실제 원인과 다르다. 에러를 구분해서 보여 주도록 고치는 건 좋은 연습 과제다. (나중에)

## 직접 눈으로 확인하기

| 흐름 단계 | 확인 방법 |
|---|---|
| ③ HTTP 요청 | `localhost:8000/docs`에서 `/health/db` → Execute → 화면에 나오는 `curl` 명령과 Response headers |
| ⑤ 라우터 | `localhost:8000/health/xyz` → `{"detail":"Not Found"}` (404) |
| ⑥ 의존성 주입 | `get_db()`의 `yield` 앞에 `print("세션 빌림")`, `finally` 안에 `print("세션 반납")`을 넣고 요청 → 백엔드 창에 순서대로 찍힘 (확인 후 지울 것) |
| ⑨ 응답 | 브라우저로 `localhost:8000/health/db`를 직접 열고 F12 → Network → 요청 클릭 → Headers |
| 실패 흐름 | `docker compose stop db` → 웹 새로고침 → 백엔드 창의 에러 로그 확인 → `docker compose start db` |
