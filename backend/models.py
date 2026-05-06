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


class UserRegisterRequest(BaseModel):
    """Request to register a verified user profile"""
    phone: str = Field(..., min_length=10, max_length=10)
    name: str = Field(..., min_length=2, max_length=80)

    @validator('name')
    def validate_name(cls, value):
        cleaned = value.strip()
        if len(cleaned) < 2:
            raise ValueError('Name must be at least 2 characters')
        return cleaned


class UserProfileResponse(BaseModel):
    """Response for a registered user profile"""
    phone: str
    name: str
    created_at: str
    last_verified_at: str


class SubscriptionOrderRequest(BaseModel):
    """Request to create a subscription payment order"""
    phone: str = Field(..., min_length=10, max_length=10)
    plan_code: str = Field(..., min_length=3, max_length=20)

    @validator('phone')
    def validate_subscription_phone(cls, value):
        if not value.isdigit():
            raise ValueError('Phone number must contain only digits')
        return value


class SubscriptionVerifyRequest(BaseModel):
    """Request to verify a completed subscription payment"""
    phone: str = Field(..., min_length=10, max_length=10)
    order_id: str = Field(..., min_length=10, max_length=80)
    payment_id: str = Field(..., min_length=10, max_length=80)
    signature: str = Field(..., min_length=10, max_length=200)

    @validator('phone')
    def validate_verify_phone(cls, value):
        if not value.isdigit():
            raise ValueError('Phone number must contain only digits')
        return value


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
    requester_phone: Optional[str] = Field(None, min_length=10, max_length=10)
    
    # Optional: For proximity-based sorting
    current_bogie: Optional[str] = Field(None, max_length=10, description="User's current bogie")
    current_seat: Optional[str] = Field(None, max_length=10, description="User's current seat")
    desired_bogie: Optional[str] = Field(None, max_length=10, description="User's desired bogie")
    desired_seat: Optional[str] = Field(None, max_length=10, description="User's desired seat")

    @validator('requester_phone')
    def validate_requester_phone(cls, value):
        if value is None:
            return value
        if not value.isdigit():
            raise ValueError('Phone number must contain only digits')
        return value


class EntryResponse(BaseModel):
    """Response for seat exchange entry"""
    id: int
    phone: str
    contact_visible: bool = False
    train_number: str
    train_date: str
    departure_time: str
    current_bogie: str
    current_seat: str
    desired_bogie: str
    desired_seat: str
    created_at: str
    proximity_details: Optional[dict] = None  # Added for proximity-based search
