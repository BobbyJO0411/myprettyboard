# 0002. 백엔드 언어/프레임워크: Python FastAPI

- 상태: 채택
- 날짜: 2026-11-10

## 배경

자동화 스크립트(크롤링, 브라우저 자동화, 파일 처리, AI 연동, 원격 PC 스크립트)가 핵심 기능이 될 가능성이 높다.

## 선택지

- **TypeScript (NestJS/Fastify/Hono)**: 웹·모바일과 언어 통일, 타입 공유 쉬움 / 자동화·AI 생태계는 Python보다 약함
- **Python (FastAPI)**: 자동화·AI·데이터 생태계 최강, API 문서(OpenAPI) 자동 생성 / 프론트와 언어가 달라짐
- **Java/Kotlin (Spring Boot)**: 한국 실무 표준 / 개인 프로젝트로는 무거움
- **Go**: 빠르고 배포 간단 / 자동화 라이브러리가 적음

## 결정

**Python FastAPI.** 관련 구성:

| 영역 | 선택 |
|---|---|
| 웹 서버 | uvicorn |
| DB | PostgreSQL 17 + SQLAlchemy 2.0 + Alembic |
| 설정 | pydantic-settings (`server/.env`) |
| 품질 | ruff (lint/format), pytest |
| 예정 | APScheduler(스케줄러), Playwright(브라우저 자동화) |

## 이유와 영향

- 웹·모바일(TypeScript)과 언어가 두 개가 된다. 대신 FastAPI의 OpenAPI 스펙으로
  TS 클라이언트를 자동 생성(`openapi-typescript` 등)해서 타입을 맞춘다. (아직 미적용)
