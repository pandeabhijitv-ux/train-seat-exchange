"""
PostgreSQL Database Configuration
Production-ready database setup
"""
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings
import os

# Database URL
if settings.environment == "production":
    # PostgreSQL for production
    DATABASE_URL = settings.database_url
else:
    # SQLite for development
    DATABASE_URL = f"sqlite:///{settings.db_folder}/train_exchange.db"

# Create engine with connection pooling
engine = create_engine(
    DATABASE_URL,
    pool_size=10,  # Number of connections to keep
    max_overflow=20,  # Max extra connections
    pool_pre_ping=True,  # Verify connections before using
    pool_recycle=3600,  # Recycle connections after 1 hour
    echo=settings.debug  # Log SQL queries in debug mode
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Dependency for FastAPI routes"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Migration helper
def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    print("✅ Database initialized successfully")


if __name__ == "__main__":
    init_db()
