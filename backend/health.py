"""
Health Check and Readiness Endpoints
For monitoring and load balancers
"""
from fastapi import APIRouter, status
from datetime import datetime
import psutil
from monitoring import metrics

health_router = APIRouter()


@health_router.get("/health")
async def health_check():
    """Basic health check - is the server running?"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }


@health_router.get("/ready")
async def readiness_check():
    """Readiness check - can the server handle requests?"""
    try:
        # Check database connection
        from database import db
        db.test_connection()
        
        return {
            "status": "ready",
            "database": "connected",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "status": "not_ready",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }, status.HTTP_503_SERVICE_UNAVAILABLE


@health_router.get("/metrics")
async def get_metrics():
    """Application metrics"""
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        "application": metrics.get_stats(),
        "system": {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "memory_available_gb": round(memory.available / (1024**3), 2),
            "disk_percent": disk.percent,
            "disk_free_gb": round(disk.free / (1024**3), 2)
        },
        "timestamp": datetime.now().isoformat()
    }
