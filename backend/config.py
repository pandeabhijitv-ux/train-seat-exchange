from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application configuration settings"""
    
    # Environment
    environment: str = "development"  # production, staging, development
    
    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True
    
    # MSG91 SMS
    msg91_auth_key: Optional[str] = None
    msg91_sender_id: str = "TRAINSEAT"
    msg91_route: str = "4"  # Transactional route
    msg91_template_id: Optional[str] = None
    
    # Razorpay
    razorpay_key_id: Optional[str] = None
    razorpay_key_secret: Optional[str] = None

    # Google Play Billing
    google_play_package_name: Optional[str] = None
    google_play_service_account_path: Optional[str] = None
    google_play_service_account_json: Optional[str] = None
    
    # PNR Verification API
    pnr_api_provider: str = "mock"  # Options: rapidapi, mock
    rapidapi_key: Optional[str] = None
    rapidapi_host: str = "pnr-status-indian-railway.p.rapidapi.com"
    rapidapi_base_url: str = "https://pnr-status-indian-railway.p.rapidapi.com"
    rapidapi_pnr_path: str = "/pnr-check/{pnr}"
    rapidapi_timeout_seconds: int = 10
    rapidapi_tls_verify: bool = True

    # Firebase Auth
    firebase_project_id: Optional[str] = None
    firebase_credentials_path: Optional[str] = None
    firebase_service_account_json: Optional[str] = None
    
    # Database
    db_folder: str = "./data"
    database_url: Optional[str] = None  # PostgreSQL URL for production
    cleanup_hours_after_departure: int = 2
    
    # Security
    otp_expiry_minutes: int = 10
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
