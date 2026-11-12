// 백엔드(FastAPI) 호출 헬퍼. 주소는 web/.env.local 의 API_URL 로 바꿀 수 있다.
export const API_URL = process.env.API_URL ?? "http://localhost:8000";

export async function apiGet<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`);
  if (!res.ok) throw new Error(`API ${path} 실패: ${res.status}`);
  return res.json() as Promise<T>;
}
