import json
from datetime import datetime
from typing import Dict, Optional

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from config import settings


class GooglePlayBillingService:
    """Verify Google Play Billing subscription purchases."""

    ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

    def __init__(self):
        self.package_name = settings.google_play_package_name
        self._credentials = None

    def _load_credentials(self):
        if self._credentials is not None:
            return self._credentials

        if settings.google_play_service_account_json:
            info = json.loads(settings.google_play_service_account_json)
            self._credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=[self.ANDROID_PUBLISHER_SCOPE],
            )
            return self._credentials

        if settings.google_play_service_account_path:
            self._credentials = service_account.Credentials.from_service_account_file(
                settings.google_play_service_account_path,
                scopes=[self.ANDROID_PUBLISHER_SCOPE],
            )
            return self._credentials

        # Fallback to Firebase credentials if explicitly provided.
        if settings.firebase_service_account_json:
            info = json.loads(settings.firebase_service_account_json)
            self._credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=[self.ANDROID_PUBLISHER_SCOPE],
            )
            return self._credentials

        if settings.firebase_credentials_path:
            self._credentials = service_account.Credentials.from_service_account_file(
                settings.firebase_credentials_path,
                scopes=[self.ANDROID_PUBLISHER_SCOPE],
            )
            return self._credentials

        raise ValueError(
            "Google Play service account credentials are missing. "
            "Set GOOGLE_PLAY_SERVICE_ACCOUNT_PATH or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON."
        )

    def _get_access_token(self) -> str:
        credentials = self._load_credentials()
        scoped = credentials.with_scopes([self.ANDROID_PUBLISHER_SCOPE])
        scoped.refresh(GoogleAuthRequest())
        if not scoped.token:
            raise ValueError("Unable to acquire Google Play API access token.")
        return scoped.token

    async def verify_subscription_purchase(self, product_id: str, purchase_token: str) -> Dict:
        if not self.package_name:
            raise ValueError(
                "GOOGLE_PLAY_PACKAGE_NAME is missing. "
                "Set package name before verifying purchases."
            )

        access_token = self._get_access_token()
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/"
            f"applications/{self.package_name}/purchases/subscriptionsv2/tokens/{purchase_token}"
        )

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        }

        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.get(url, headers=headers)

        if response.status_code != 200:
            raise ValueError(
                f"Google Play verification failed ({response.status_code}): {response.text}"
            )

        payload = response.json()
        line_items = payload.get("lineItems", [])

        matching_line_item: Optional[Dict] = None
        for item in line_items:
            if item.get("productId") == product_id:
                matching_line_item = item
                break

        if matching_line_item is None and line_items:
            # If caller passed a product_id alias, fall back to first line item.
            matching_line_item = line_items[0]

        if matching_line_item is None:
            raise ValueError("No subscription line item found in Google Play response.")

        expiry_time = matching_line_item.get("expiryTime")
        state = payload.get("subscriptionState", "")

        is_active = state in {
            "SUBSCRIPTION_STATE_ACTIVE",
            "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
        }

        latest_order_id = payload.get("latestOrderId") or ""

        return {
            "is_active": is_active,
            "state": state,
            "product_id": matching_line_item.get("productId"),
            "expiry_time": expiry_time,
            "latest_order_id": latest_order_id,
            "raw": payload,
        }

    @staticmethod
    def parse_expiry(expiry_time: Optional[str]) -> Optional[datetime]:
        if not expiry_time:
            return None
        try:
            return datetime.fromisoformat(expiry_time.replace("Z", "+00:00"))
        except Exception:
            return None


google_play_billing_service = GooglePlayBillingService()
