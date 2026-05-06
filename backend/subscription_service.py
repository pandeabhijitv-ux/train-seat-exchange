import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta
from typing import Dict, Optional

from config import settings


class SubscriptionService:
    """Manage subscription plans and active entitlements."""

    PLANS = {
        "monthly": {
            "code": "monthly",
            "name": "Monthly",
            "price_inr": 125,
            "duration_days": 30,
            "description": "Full access for 30 days",
        },
        "quarterly": {
            "code": "quarterly",
            "name": "Quarterly",
            "price_inr": 275,
            "duration_days": 90,
            "description": "Full access for 90 days",
        },
        "yearly": {
            "code": "yearly",
            "name": "Yearly",
            "price_inr": 950,
            "duration_days": 365,
            "description": "Full access for 365 days",
        },
    }

    PLAY_PRODUCT_TO_PLAN = {
        "monthly_125": "monthly",
        "quarterly_275": "quarterly",
        "yearly_950": "yearly",
    }

    PLAN_TO_PLAY_PRODUCT = {value: key for key, value in PLAY_PRODUCT_TO_PLAN.items()}

    def __init__(self):
        self.db_path = os.path.join(settings.db_folder, "subscriptions.db")
        os.makedirs(settings.db_folder, exist_ok=True)
        self._initialize_db()

    @contextmanager
    def _get_connection(self):
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

    def _initialize_db(self):
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS subscriptions (
                    phone TEXT PRIMARY KEY,
                    plan_code TEXT NOT NULL,
                    plan_name TEXT NOT NULL,
                    amount_paid INTEGER NOT NULL,
                    starts_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    status TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    source_order_id TEXT,
                    source_payment_id TEXT
                )
                """
            )

            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS pending_subscription_orders (
                    order_id TEXT PRIMARY KEY,
                    phone TEXT NOT NULL,
                    plan_code TEXT NOT NULL,
                    amount_paid INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    consumed INTEGER DEFAULT 0
                )
                """
            )

    def get_plans(self) -> list[Dict]:
        return [
            {
                **plan,
                "amount_paise": plan["price_inr"] * 100,
                "play_product_id": self.PLAN_TO_PLAY_PRODUCT.get(plan["code"]),
            }
            for plan in self.PLANS.values()
        ]

    def get_plan(self, plan_code: str) -> Optional[Dict]:
        return self.PLANS.get(plan_code)

    def get_plan_by_product_id(self, product_id: str) -> Optional[Dict]:
        plan_code = self.PLAY_PRODUCT_TO_PLAN.get(product_id)
        if not plan_code:
            return None
        return self.get_plan(plan_code)

    def save_pending_order(self, order_id: str, phone: str, plan_code: str, amount_paid: int):
        now = datetime.utcnow().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO pending_subscription_orders
                (order_id, phone, plan_code, amount_paid, created_at, consumed)
                VALUES (?, ?, ?, ?, ?, 0)
                """,
                (order_id, phone, plan_code, amount_paid, now),
            )

    def get_pending_order(self, order_id: str) -> Optional[Dict]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT order_id, phone, plan_code, amount_paid, created_at, consumed
                FROM pending_subscription_orders
                WHERE order_id = ?
                """,
                (order_id,),
            )
            row = cursor.fetchone()
            return dict(row) if row else None

    def consume_pending_order(self, order_id: str):
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE pending_subscription_orders
                SET consumed = 1
                WHERE order_id = ?
                """,
                (order_id,),
            )

    def get_subscription(self, phone: str) -> Optional[Dict]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT phone, plan_code, plan_name, amount_paid, starts_at, expires_at,
                       status, updated_at, source_order_id, source_payment_id
                FROM subscriptions
                WHERE phone = ?
                """,
                (phone,),
            )
            row = cursor.fetchone()
            if not row:
                return None

            subscription = dict(row)
            is_active = self._is_active(subscription)
            if subscription["status"] != "active" and is_active:
                subscription["status"] = "active"
            if subscription["status"] == "active" and not is_active:
                subscription["status"] = "expired"

            subscription["is_active"] = is_active
            return subscription

    def is_active(self, phone: str) -> bool:
        subscription = self.get_subscription(phone)
        if not subscription:
            return False
        return subscription["is_active"]

    def activate_subscription(
        self,
        phone: str,
        plan_code: str,
        amount_paid: int,
        order_id: str,
        payment_id: str,
    ) -> Dict:
        plan = self.get_plan(plan_code)
        if not plan:
            raise ValueError("Invalid plan code")

        now = datetime.utcnow()
        existing = self.get_subscription(phone)

        if existing and existing.get("is_active"):
            start_at = datetime.fromisoformat(existing["expires_at"])
        else:
            start_at = now

        expires_at = start_at + timedelta(days=plan["duration_days"])
        now_iso = now.isoformat()
        start_iso = start_at.isoformat()
        expires_iso = expires_at.isoformat()

        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO subscriptions
                (phone, plan_code, plan_name, amount_paid, starts_at, expires_at, status,
                 updated_at, source_order_id, source_payment_id)
                VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)
                """,
                (
                    phone,
                    plan["code"],
                    plan["name"],
                    amount_paid,
                    start_iso,
                    expires_iso,
                    now_iso,
                    order_id,
                    payment_id,
                ),
            )

        return {
            "phone": phone,
            "plan_code": plan["code"],
            "plan_name": plan["name"],
            "starts_at": start_iso,
            "expires_at": expires_iso,
            "status": "active",
            "is_active": True,
        }

    def _is_active(self, subscription: Dict) -> bool:
        if subscription.get("status") != "active":
            return False
        try:
            expires_at = datetime.fromisoformat(subscription["expires_at"])
        except Exception:
            return False
        return expires_at > datetime.utcnow()


subscription_service = SubscriptionService()
