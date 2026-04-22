import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from typing import Dict, Optional

from config import settings


class UserRegistry:
    """Persist lightweight registered user profiles for OTP-verified users."""

    def __init__(self):
        self.db_folder = settings.db_folder
        os.makedirs(self.db_folder, exist_ok=True)
        self.db_path = os.path.join(self.db_folder, "user_profiles.db")
        self.initialize_table()

    @contextmanager
    def get_connection(self):
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception as exc:
            conn.rollback()
            raise exc
        finally:
            conn.close()

    def initialize_table(self):
        with self.get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS user_profiles (
                    phone TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    last_verified_at TIMESTAMP NOT NULL
                )
                """
            )

    def register_user(self, phone: str, name: str) -> Dict:
        now = datetime.now().isoformat()
        with self.get_connection() as conn:
            cursor = conn.execute(
                "SELECT created_at FROM user_profiles WHERE phone = ?",
                (phone,),
            )
            row = cursor.fetchone()
            created_at = row["created_at"] if row else now

            conn.execute(
                """
                INSERT OR REPLACE INTO user_profiles
                (phone, name, created_at, last_verified_at)
                VALUES (?, ?, ?, ?)
                """,
                (phone, name.strip(), created_at, now),
            )

        return self.get_user(phone)

    def get_user(self, phone: str) -> Optional[Dict]:
        with self.get_connection() as conn:
            cursor = conn.execute(
                "SELECT phone, name, created_at, last_verified_at FROM user_profiles WHERE phone = ?",
                (phone,),
            )
            row = cursor.fetchone()
            return dict(row) if row else None

    def is_registered(self, phone: str) -> bool:
        return self.get_user(phone) is not None


user_registry = UserRegistry()