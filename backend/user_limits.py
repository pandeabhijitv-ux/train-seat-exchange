"""
User Entry Limits Tracker
Tracks total entries per phone number to enforce 10-entry limit
"""
import sqlite3
import os
from contextlib import contextmanager
from config import settings


class UserLimitsTracker:
    """Track user entry limits by phone number"""
    
    MAX_ENTRIES_PER_USER = 10
    
    def __init__(self):
        self.db_path = os.path.join(settings.db_folder, "user_limits.db")
        os.makedirs(settings.db_folder, exist_ok=True)
        self._initialize_db()
    
    def _initialize_db(self):
        """Create user limits table"""
        with self._get_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS user_entries (
                    phone TEXT PRIMARY KEY,
                    total_entries INTEGER DEFAULT 0,
                    last_entry_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_phone 
                ON user_entries(phone)
            """)
    
    @contextmanager
    def _get_connection(self):
        """Context manager for database connection"""
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()
    
    def get_user_entry_count(self, phone: str) -> int:
        """Get total entries created by user"""
        with self._get_connection() as conn:
            cursor = conn.execute("""
                SELECT total_entries FROM user_entries 
                WHERE phone = ?
            """, (phone,))
            
            row = cursor.fetchone()
            return row['total_entries'] if row else 0
    
    def can_create_entry(self, phone: str) -> bool:
        """Check if user can create more entries"""
        count = self.get_user_entry_count(phone)
        return count < self.MAX_ENTRIES_PER_USER
    
    def increment_entry_count(self, phone: str) -> int:
        """Increment entry count for user"""
        with self._get_connection() as conn:
            # Try to update existing record
            cursor = conn.execute("""
                UPDATE user_entries 
                SET total_entries = total_entries + 1,
                    last_entry_at = CURRENT_TIMESTAMP
                WHERE phone = ?
            """, (phone,))
            
            # If no row was updated, insert new record
            if cursor.rowcount == 0:
                conn.execute("""
                    INSERT INTO user_entries (phone, total_entries, last_entry_at)
                    VALUES (?, 1, CURRENT_TIMESTAMP)
                """, (phone,))
                return 1
            else:
                # Get updated count
                cursor = conn.execute("""
                    SELECT total_entries FROM user_entries 
                    WHERE phone = ?
                """, (phone,))
                return cursor.fetchone()['total_entries']
    
    def get_remaining_entries(self, phone: str) -> int:
        """Get remaining entries for user"""
        used = self.get_user_entry_count(phone)
        return max(0, self.MAX_ENTRIES_PER_USER - used)


# Global instance
user_limits = UserLimitsTracker()
