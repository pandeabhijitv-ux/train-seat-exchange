import sqlite3
import os
from datetime import datetime, timedelta
from typing import List, Optional, Dict
from contextlib import contextmanager
from config import settings


class Database:
    """Database manager for train-specific SQLite files"""
    
    def __init__(self):
        self.db_folder = settings.db_folder
        os.makedirs(self.db_folder, exist_ok=True)
    
    def _get_db_path(self, train_number: str, train_date: str) -> str:
        """Generate database file path for a specific train and date"""
        # Format: train_12345_20251222.db
        date_formatted = train_date.replace('-', '')
        return os.path.join(self.db_folder, f"train_{train_number}_{date_formatted}.db")
    
    @contextmanager
    def get_connection(self, train_number: str, train_date: str):
        """Context manager for database connection with proper locking"""
        db_path = self._get_db_path(train_number, train_date)
        conn = sqlite3.connect(db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        
        # Enable WAL mode for better concurrent access
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=30000")
        
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()
    
    def initialize_table(self, train_number: str, train_date: str):
        """Create table if it doesn't exist"""
        with self.get_connection(train_number, train_date) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS seat_exchanges (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone TEXT NOT NULL,
                    train_number TEXT NOT NULL,
                    train_date TEXT NOT NULL,
                    departure_time TEXT NOT NULL,
                    current_bogie TEXT NOT NULL,
                    current_seat TEXT NOT NULL,
                    desired_bogie TEXT NOT NULL,
                    desired_seat TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(phone, train_number, train_date)
                )
            """)
            
            # Create indexes for faster searches
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_desired_bogie 
                ON seat_exchanges(desired_bogie)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_current_bogie 
                ON seat_exchanges(current_bogie)
            """)
    
    def create_entry(self, entry_data: Dict) -> int:
        """Create a new seat exchange entry"""
        train_number = entry_data['train_number']
        train_date = entry_data['train_date']
        
        self.initialize_table(train_number, train_date)
        
        with self.get_connection(train_number, train_date) as conn:
            cursor = conn.execute("""
                INSERT INTO seat_exchanges 
                (phone, train_number, train_date, departure_time,
                 current_bogie, current_seat, desired_bogie, desired_seat)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                entry_data['phone'],
                train_number,
                train_date,
                entry_data['departure_time'],
                entry_data['current_bogie'],
                entry_data['current_seat'],
                entry_data['desired_bogie'],
                entry_data['desired_seat']
            ))
            return cursor.lastrowid
    
    def search_entries(self, train_number: str, train_date: str,
                      bogie: Optional[str] = None,
                      exclude_phone: Optional[str] = None) -> List[Dict]:
        """Search for seat exchange entries"""
        db_path = self._get_db_path(train_number, train_date)
        
        # If file doesn't exist, return empty list
        if not os.path.exists(db_path):
            return []
        
        with self.get_connection(train_number, train_date) as conn:
            if bogie:
                query = """
                    SELECT * FROM seat_exchanges
                    WHERE (current_bogie = ? OR desired_bogie = ?)
                """
                params: List[str] = [bogie, bogie]
            else:
                query = """
                    SELECT * FROM seat_exchanges
                    WHERE 1 = 1
                """
                params = []

            if exclude_phone:
                query += " AND phone != ?"
                params.append(exclude_phone)

            query += " ORDER BY created_at DESC"
            cursor = conn.execute(query, tuple(params))
            
            rows = cursor.fetchall()
            return [dict(row) for row in rows]

    def find_exact_matches(self, entry_data: Dict) -> List[Dict]:
        """Find reciprocal matches for an entry in the same train/date."""
        train_number = entry_data['train_number']
        train_date = entry_data['train_date']
        db_path = self._get_db_path(train_number, train_date)

        if not os.path.exists(db_path):
            return []

        with self.get_connection(train_number, train_date) as conn:
            cursor = conn.execute(
                """
                SELECT * FROM seat_exchanges
                WHERE phone != ?
                  AND UPPER(current_bogie) = UPPER(?)
                  AND UPPER(current_seat) = UPPER(?)
                  AND UPPER(desired_bogie) = UPPER(?)
                  AND UPPER(desired_seat) = UPPER(?)
                ORDER BY created_at DESC
                """,
                (
                    entry_data['phone'],
                    entry_data['desired_bogie'],
                    entry_data['desired_seat'],
                    entry_data['current_bogie'],
                    entry_data['current_seat'],
                ),
            )
            rows = cursor.fetchall()
            return [dict(row) for row in rows]

    def get_user_entries(self, phone: str) -> List[Dict]:
        """Return all active entries for a phone across train databases."""
        if not os.path.exists(self.db_folder):
            return []

        entries: List[Dict] = []

        for filename in os.listdir(self.db_folder):
            if not filename.endswith('.db'):
                continue

            if filename == 'user_profiles.db':
                continue

            try:
                parts = filename.replace('.db', '').split('_')
                if len(parts) != 3:
                    continue

                train_number = parts[1]
                date_str = parts[2]
                train_date = datetime.strptime(date_str, '%Y%m%d').strftime('%Y-%m-%d')

                with self.get_connection(train_number, train_date) as conn:
                    cursor = conn.execute(
                        """
                        SELECT * FROM seat_exchanges
                        WHERE phone = ?
                        ORDER BY created_at DESC
                        """,
                        (phone,),
                    )
                    rows = cursor.fetchall()
                    entries.extend([dict(row) for row in rows])
            except Exception:
                continue

        entries.sort(key=lambda item: item.get('created_at', ''), reverse=True)
        return entries
    
    def check_duplicate_entry(self, phone: str, train_number: str, 
                            train_date: str) -> bool:
        """Check if user already has an entry for this train"""
        db_path = self._get_db_path(train_number, train_date)
        
        if not os.path.exists(db_path):
            return False
        
        with self.get_connection(train_number, train_date) as conn:
            cursor = conn.execute("""
                SELECT COUNT(*) FROM seat_exchanges 
                WHERE phone = ? AND train_number = ? AND train_date = ?
            """, (phone, train_number, train_date))
            count = cursor.fetchone()[0]
            return count > 0
    
    def cleanup_expired_trains(self):
        """Delete database files for expired trains (departure + 2 hours)"""
        if not os.path.exists(self.db_folder):
            return
        
        deleted_count = 0
        current_time = datetime.now()
        
        for filename in os.listdir(self.db_folder):
            if not filename.endswith('.db'):
                continue
            
            try:
                # Parse filename: train_12345_20251222.db
                parts = filename.replace('.db', '').split('_')
                if len(parts) != 3:
                    continue
                
                train_number = parts[1]
                date_str = parts[2]  # Format: 20251222
                
                # Convert to datetime
                train_date = datetime.strptime(date_str, '%Y%m%d')
                
                # Get departure time from database
                db_path = os.path.join(self.db_folder, filename)
                conn = sqlite3.connect(db_path)
                cursor = conn.execute("""
                    SELECT departure_time FROM seat_exchanges LIMIT 1
                """)
                row = cursor.fetchone()
                conn.close()
                
                if not row:
                    continue
                
                departure_time = datetime.strptime(row[0], '%H:%M').time()
                train_departure = datetime.combine(train_date.date(), departure_time)
                
                # Check if expired (departure + cleanup hours)
                expiry_time = train_departure + timedelta(
                    hours=settings.cleanup_hours_after_departure
                )
                
                if current_time > expiry_time:
                    os.remove(db_path)
                    # Also remove WAL and SHM files if they exist
                    for ext in ['-wal', '-shm']:
                        wal_file = db_path + ext
                        if os.path.exists(wal_file):
                            os.remove(wal_file)
                    deleted_count += 1
                    
            except Exception as e:
                print(f"Error cleaning up {filename}: {e}")
                continue
        
        return deleted_count


# Singleton instance
db = Database()
