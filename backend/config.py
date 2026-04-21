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
    msg91_auth_key: str
    msg91_sender_id: str = "TRAINSEAT"
    msg91_route: str = "4"  # Transactional route
    
    # Razorpay
    razorpay_key_id: str
    razorpay_key_secret: str
    
    # PNR Verification API
    pnr_api_provider: str = "mock"  # Options: rapidapi, mock
    rapidapi_key: Optional[str] = None
    rapidapi_host: str = "pnr-status-indian-railway.p.rapidapi.com"
    
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
