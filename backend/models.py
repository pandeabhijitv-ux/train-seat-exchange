from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime


class PhoneVerifyRequest(BaseModel):
    """Request to send OTP to phone number"""
    phone: str = Field(..., min_length=10, max_length=10, description="10-digit Indian mobile number")
    
    @validator('phone')
    def validate_phone(cls, v):
        if not v.isdigit():
            raise ValueError('Phone number must contain only digits')
        if not v.startswith(('6', '7', '8', '9')):
            raise ValueError('Invalid Indian mobile number')
        return v


class OTPVerifyRequest(BaseModel):
    """Request to verify OTP"""
    phone: str = Field(..., min_length=10, max_length=10)
    otp: str = Field(..., min_length=4, max_length=6)


class SeatExchangeEntry(BaseModel):
    """Request to create seat exchange entry"""
    phone: str = Field(..., min_length=10, max_length=10)
    
    train_number: str = Field(..., min_length=5, max_length=10, description="Train number")
    train_date: str = Field(..., description="Train departure date (YYYY-MM-DD)")
    departure_time: str = Field(..., description="Departure time (HH:MM)")
    
    current_bogie: str = Field(..., max_length=10, description="Current bogie (e.g., B3, A2)")
    current_seat: str = Field(..., max_length=10, description="Current seat number")
    
    desired_bogie: str = Field(..., max_length=10, description="Desired bogie")
    desired_seat: str = Field(..., max_length=10, description="Desired seat number")
    
    @validator('train_date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, '%Y-%m-%d')
        except ValueError:
            raise ValueError('Date must be in YYYY-MM-DD format')
        return v
    
    @validator('departure_time')
    def validate_time(cls, v):
        try:
            datetime.strptime(v, '%H:%M')
        except ValueError:
            raise ValueError('Time must be in HH:MM format')
        return v


class SearchRequest(BaseModel):
    """Request to search entries"""
    train_number: str = Field(..., min_length=5, max_length=10)
    train_date: str = Field(..., description="Train date (YYYY-MM-DD)")
    bogie: Optional[str] = Field(None, max_length=10, description="Filter by bogie")
    
    # Optional: For proximity-based sorting
    current_bogie: Optional[str] = Field(None, max_length=10, description="User's current bogie")
    current_seat: Optional[str] = Field(None, max_length=10, description="User's current seat")
    desired_bogie: Optional[str] = Field(None, max_length=10, description="User's desired bogie")
    desired_seat: Optional[str] = Field(None, max_length=10, description="User's desired seat")


class EntryResponse(BaseModel):
    """Response for seat exchange entry"""
    id: int
    phone: str
    train_number: str
    train_date: str
    departure_time: str
    current_bogie: str
    current_seat: str
    desired_bogie: str
    desired_seat: str
    created_at: str
    proximity_details: Optional[dict] = None  # Added for proximity-based search
