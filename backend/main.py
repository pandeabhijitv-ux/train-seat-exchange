from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from routes import router
from scheduler import start_scheduler
from config import settings
import uvicorn


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan events for startup and shutdown"""
    # Startup
    print("Starting Train Seat Exchange API...")
    scheduler = start_scheduler()
    
    yield
    
    # Shutdown
    print("Shutting down...")
    scheduler.shutdown()


# Create FastAPI app
app = FastAPI(
    title="Train Seat Exchange API",
    description="API for exchanging train seat bookings between passengers",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your mobile app domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(router, prefix="/api/v1", tags=["API"])

# Serve static files
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Train Seat Exchange API",
        "version": "1.0.0",
        "docs": "/docs",
        "mobile_test": "/static/mobile-test.html"
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )
