import httpx
import random
from datetime import datetime, timedelta
from typing import Dict, Optional
from config import settings


class OTPService:
    """Service for sending and verifying OTP via MSG91"""
    
    def __init__(self):
        self.auth_key = settings.msg91_auth_key
        self.sender_id = settings.msg91_sender_id
        self.route = settings.msg91_route
        self.base_url = "https://api.msg91.com/api/v5"
        
        # In-memory OTP storage (for production, use Redis)
        self.otp_store: Dict[str, Dict] = {}
    
    def generate_otp(self) -> str:
        """Generate 6-digit OTP"""
        return str(random.randint(100000, 999999))
    
    async def send_otp(self, phone: str) -> Dict:
        """Send OTP to phone number via MSG91"""
        otp = self.generate_otp()
        
        # Store OTP with expiry
        expiry_time = datetime.now() + timedelta(minutes=settings.otp_expiry_minutes)
        self.otp_store[phone] = {
            'otp': otp,
            'expiry': expiry_time,
            'verified': False
        }
        
        # Send SMS via MSG91
        try:
            async with httpx.AsyncClient() as client:
                url = f"{self.base_url}/otp"
                params = {
                    "template_id": "your_template_id_here",  # Create template in MSG91 dashboard
                    "mobile": f"91{phone}",  # Indian country code
                    "authkey": self.auth_key,
                    "otp": otp
                }
                
                # Alternative: Use Flow API with custom template
                # For now, using simple SMS API
                sms_url = "https://api.msg91.com/api/sendhttp.php"
                sms_params = {
                    "authkey": self.auth_key,
                    "mobiles": f"91{phone}",
                    "message": f"Your OTP for Train Seat Exchange is {otp}. Valid for {settings.otp_expiry_minutes} minutes.",
                    "sender": self.sender_id,
                    "route": self.route
                }
                
                response = await client.get(sms_url, params=sms_params, timeout=10.0)
                
                if response.status_code == 200:
                    return {
                        "success": True,
                        "message": "OTP sent successfully",
                        "expires_in_minutes": settings.otp_expiry_minutes
                    }
                else:
                    return {
                        "success": False,
                        "message": "Failed to send OTP",
                        "error": response.text
                    }
                    
        except Exception as e:
            # In development, store OTP without actually sending
            if settings.debug:
                print(f"DEBUG MODE: OTP for {phone} is {otp}")
                return {
                    "success": True,
                    "message": f"DEBUG: OTP sent (check console)",
                    "debug_otp": otp  # Remove in production
                }
            
            return {
                "success": False,
                "message": "Error sending OTP",
                "error": str(e)
            }
    
    def verify_otp(self, phone: str, otp: str) -> Dict:
        """Verify OTP for phone number"""
        stored_data = self.otp_store.get(phone)
        
        if not stored_data:
            return {
                "success": False,
                "message": "OTP not found. Please request a new OTP."
            }
        
        # Check expiry
        if datetime.now() > stored_data['expiry']:
            del self.otp_store[phone]
            return {
                "success": False,
                "message": "OTP expired. Please request a new OTP."
            }
        
        # Check if already verified
        if stored_data['verified']:
            return {
                "success": False,
                "message": "OTP already used. Please request a new OTP."
            }
        
        # Verify OTP
        if stored_data['otp'] == otp:
            stored_data['verified'] = True
            return {
                "success": True,
                "message": "OTP verified successfully",
                "phone": phone
            }
        else:
            return {
                "success": False,
                "message": "Invalid OTP. Please try again."
            }
    
    def is_phone_verified(self, phone: str) -> bool:
        """Check if phone number is verified"""
        stored_data = self.otp_store.get(phone)
        if not stored_data:
            return False
        
        # Check if verified and not expired
        is_verified = stored_data.get('verified', False)
        not_expired = datetime.now() <= stored_data['expiry']
        
        return is_verified and not_expired
    
    def cleanup_expired_otps(self):
        """Remove expired OTPs from memory"""
        current_time = datetime.now()
        expired_phones = [
            phone for phone, data in self.otp_store.items()
            if current_time > data['expiry']
        ]
        
        for phone in expired_phones:
            del self.otp_store[phone]
        
        return len(expired_phones)


# Singleton instance
otp_service = OTPService()
