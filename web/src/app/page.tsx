import { Suspense } from "react";

import { apiGet } from "@/lib/api";

async function getDbStatus(): Promise<string | null> {
  try {
    const data = await apiGet<{ status: string; db: string }>("/health/db");
    return data.db;
  } catch {
    return null;
  }
}

async function ServerStatus() {
  const db = await getDbStatus();
  if (db === null) {
    return <p className="text-rose-600">백엔드에 연결할 수 없습니다 (server 실행 여부 확인)</p>;
  }
  return <p className="text-emerald-600">백엔드 연결됨 · DB {db}</p>;
}

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 px-4 py-16">
      <h1 className="text-3xl font-bold">myprettyboard</h1>
      <p className="text-zinc-500">할 일 · 일정 · 블로그 · 자동화 · 원격 PC를 한곳에서.</p>
      <Suspense fallback={<p className="text-zinc-400">백엔드 상태 확인 중…</p>}>
        <ServerStatus />
      </Suspense>
    </main>
  );
}
