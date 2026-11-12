"""DB 연결. SQLAlchemy 2.0 스타일."""

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from server.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False)


class Base(DeclarativeBase):
    """모든 모델이 상속하는 베이스 클래스."""


def get_db() -> Iterator[Session]:
    """FastAPI 의존성: 요청마다 세션을 열고 닫는다."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
