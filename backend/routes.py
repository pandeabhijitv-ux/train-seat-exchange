from fastapi import APIRouter, HTTPException, status
from models import (
    PhoneVerifyRequest, OTPVerifyRequest, SeatExchangeEntry, SearchRequest, EntryResponse
)
from otp_service import otp_service
from pnr_service import pnr_service
from database import db
from user_limits import user_limits
from proximity_matcher import ProximityMatcher
from typing import List
from pydantic import BaseModel

router = APIRouter()


# ============== PNR Verification Endpoint ==============

class PNRVerifyRequest(BaseModel):
    """Request to verify PNR"""
    pnr: str

@router.post("/pnr/verify")
async def verify_pnr(request: PNRVerifyRequest):
    """Verify PNR and get booking details"""
    if len(request.pnr) != 10 or not request.pnr.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid PNR format. PNR must be 10 digits"
        )
    
    result = await pnr_service.verify_pnr(request.pnr)
    
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=result.get('message', 'PNR not found or invalid')
        )
    
    return result


# ============== OTP Endpoints ==============

@router.post("/otp/send")
async def send_otp(request: PhoneVerifyRequest):
    """Send OTP to phone number"""
    result = await otp_service.send_otp(request.phone)
    
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get('message', 'Failed to send OTP')
        )
    
    return result


@router.post("/otp/verify")
async def verify_otp(request: OTPVerifyRequest):
    """Verify OTP"""
    result = otp_service.verify_otp(request.phone, request.otp)
    
    if not result['success']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result['message']
        )
    
    return result


# ============== User Limits Endpoint ==============

@router.get("/user/limits/{phone}")
async def get_user_limits(phone: str):
    """Get user entry limits"""
    if len(phone) != 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number format"
        )
    
    total_entries = user_limits.get_user_entry_count(phone)
    remaining = user_limits.get_remaining_entries(phone)
    
    return {
        "success": True,
        "phone": phone,
        "total_entries": total_entries,
        "max_entries": user_limits.MAX_ENTRIES_PER_USER,
        "remaining_entries": remaining,
        "can_create_more": remaining > 0
    }


# ============== Seat Exchange Endpoints ==============

@router.post("/entry/create", response_model=dict)
async def create_entry(request: SeatExchangeEntry):
    """Create seat exchange entry"""
    
    # Verify phone is OTP verified
    if not otp_service.is_phone_verified(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Phone number not verified."
        )
    
    # Check for duplicate entry (one entry per train per phone)
    if db.check_duplicate_entry(request.phone, request.train_number, request.train_date):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have an entry for this train. One entry per person per train allowed."
        )
    
    try:
        entry_id = db.create_entry(request.dict())
        
        # Track entry count for analytics (not enforced server-side)
        new_count = user_limits.increment_entry_count(request.phone)
        
        return {
            "success": True,
            "message": "Entry created successfully",
            "entry_id": entry_id,
            "total_entries": new_count,
            "note": "Your entry is now visible to other users."
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create entry: {str(e)}"
        )


@router.post("/entry/search", response_model=List[EntryResponse])
async def search_entries(request: SearchRequest):
    """Search for seat exchange entries with optional proximity sorting"""
    try:
        entries = db.search_entries(
            request.train_number,
            request.train_date,
            request.bogie
        )
        
        # If proximity parameters provided, sort by proximity
        if all([
            request.current_bogie,
            request.current_seat,
            request.desired_bogie,
            request.desired_seat
        ]):
            entries = ProximityMatcher.sort_by_proximity(
                entries,
                request.current_bogie,
                request.current_seat,
                request.desired_bogie,
                request.desired_seat
            )
        
        return entries
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )


# ============== Health Check ==============

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Train Seat Exchange API"
    }
