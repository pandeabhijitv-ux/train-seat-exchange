"""
Security Middleware and Rate Limiting
"""
from fastapi import Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import time
from collections import defaultdict
from datetime import datetime, timedelta

# Rate limiter
limiter = Limiter(key_func=get_remote_address)

# Track failed login attempts
failed_attempts = defaultdict(list)
LOCKOUT_DURATION = 300  # 5 minutes
MAX_ATTEMPTS = 5


def check_rate_limit(ip: str, action: str) -> bool:
    """Check if IP is rate limited for specific action"""
    key = f"{ip}:{action}"
    now = datetime.now()
    
    # Clean old attempts
    failed_attempts[key] = [
        attempt for attempt in failed_attempts[key]
        if now - attempt < timedelta(seconds=LOCKOUT_DURATION)
    ]
    
    # Check if locked out
    if len(failed_attempts[key]) >= MAX_ATTEMPTS:
        return False
    
    return True


def record_failed_attempt(ip: str, action: str):
    """Record a failed authentication attempt"""
    key = f"{ip}:{action}"
    failed_attempts[key].append(datetime.now())


def setup_security_middleware(app):
    """Setup all security middleware"""
    
    # CORS - Restrict in production
    from config import settings
    
    allowed_origins = ["*"] if settings.debug else [
        "https://your-domain.com",
        "https://www.your-domain.com"
    ]
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
        allow_headers=["*"],
        max_age=3600,
    )
    
    # Rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    
    return app


# Security headers middleware
async def security_headers_middleware(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)
    
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    
    return response
