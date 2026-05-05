import json
from typing import Dict, Optional

import firebase_admin
from firebase_admin import auth, credentials

from config import settings


class FirebaseAuthService:
    def __init__(self):
        self._app: Optional[firebase_admin.App] = None

    def _load_credentials(self):
        if settings.firebase_service_account_json:
            return credentials.Certificate(json.loads(settings.firebase_service_account_json))

        if settings.firebase_credentials_path:
            return credentials.Certificate(settings.firebase_credentials_path)

        raise RuntimeError(
            "Firebase Admin is not configured. Set FIREBASE_CREDENTIALS_PATH or FIREBASE_SERVICE_ACCOUNT_JSON."
        )

    def _get_app(self):
        if self._app is not None:
            return self._app

        try:
            self._app = firebase_admin.get_app("rail-seat-exchange")
            return self._app
        except ValueError:
            pass

        options = {}
        if settings.firebase_project_id:
            options["projectId"] = settings.firebase_project_id

        self._app = firebase_admin.initialize_app(
            credential=self._load_credentials(),
            options=options,
            name="rail-seat-exchange",
        )
        return self._app

    @staticmethod
    def _normalize_phone(phone_number: str) -> str:
        normalized = phone_number.strip()
        if normalized.startswith("+91"):
            normalized = normalized[3:]
        elif normalized.startswith("91") and len(normalized) == 12:
            normalized = normalized[2:]
        return normalized

    def verify_id_token(self, id_token: str, expected_phone: Optional[str] = None) -> Dict[str, str]:
        decoded = auth.verify_id_token(id_token, app=self._get_app())
        phone_number = decoded.get("phone_number")
        if not phone_number:
            raise ValueError("Firebase token does not contain a verified phone number.")

        normalized_phone = self._normalize_phone(str(phone_number))
        if expected_phone and normalized_phone != expected_phone:
            raise ValueError("Firebase phone number does not match the requested phone.")

        return {
            "uid": str(decoded.get("uid", "")),
            "phone": normalized_phone,
        }


firebase_auth_service = FirebaseAuthService()