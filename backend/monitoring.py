"""
Logging and Monitoring Configuration
"""
import logging
from logging.handlers import RotatingFileHandler
import sys
from config import settings

# Setup logging
def setup_logging():
    """Configure application logging"""
    
    # Create logger
    logger = logging.getLogger("train_exchange")
    logger.setLevel(logging.DEBUG if settings.debug else logging.INFO)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_format = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(console_format)
    
    # File handler (rotating)
    if not settings.debug:
        file_handler = RotatingFileHandler(
            'logs/app.log',
            maxBytes=10485760,  # 10MB
            backupCount=5
        )
        file_handler.setLevel(logging.WARNING)
        file_format = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s - %(pathname)s:%(lineno)d'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)
    
    logger.addHandler(console_handler)
    
    return logger


# Application metrics
class Metrics:
    """Track application metrics"""
    
    def __init__(self):
        self.requests_total = 0
        self.requests_failed = 0
        self.otp_sent = 0
        self.payments_processed = 0
        self.entries_created = 0
        self.pnr_verifications = 0
    
    def increment(self, metric: str):
        """Increment a metric counter"""
        if hasattr(self, metric):
            setattr(self, metric, getattr(self, metric) + 1)
    
    def get_stats(self):
        """Get current stats"""
        return {
            "requests_total": self.requests_total,
            "requests_failed": self.requests_failed,
            "otp_sent": self.otp_sent,
            "payments_processed": self.payments_processed,
            "entries_created": self.entries_created,
            "pnr_verifications": self.pnr_verifications
        }


metrics = Metrics()
logger = setup_logging()
