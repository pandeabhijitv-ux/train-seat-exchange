from apscheduler.schedulers.background import BackgroundScheduler
from database import db
from otp_service import otp_service
from datetime import datetime


def cleanup_expired_trains():
    """Background job to cleanup expired train data"""
    try:
        deleted = db.cleanup_expired_trains()
        print(f"[{datetime.now()}] Cleaned up {deleted} expired train database(s)")
    except Exception as e:
        print(f"[{datetime.now()}] Error during cleanup: {e}")


def cleanup_expired_otps():
    """Background job to cleanup expired OTPs"""
    try:
        deleted = otp_service.cleanup_expired_otps()
        print(f"[{datetime.now()}] Cleaned up {deleted} expired OTP(s)")
    except Exception as e:
        print(f"[{datetime.now()}] Error during OTP cleanup: {e}")


def start_scheduler():
    """Start background scheduler for cleanup jobs"""
    scheduler = BackgroundScheduler()
    
    # Cleanup expired trains every 30 minutes
    scheduler.add_job(
        cleanup_expired_trains,
        'interval',
        minutes=30,
        id='cleanup_trains',
        name='Cleanup expired train databases'
    )
    
    # Cleanup expired OTPs every 10 minutes
    scheduler.add_job(
        cleanup_expired_otps,
        'interval',
        minutes=10,
        id='cleanup_otps',
        name='Cleanup expired OTPs'
    )
    
    scheduler.start()
    print("Background scheduler started")
    
    return scheduler
