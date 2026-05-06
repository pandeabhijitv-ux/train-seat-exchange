import razorpay
import hmac
import hashlib
from typing import Dict
from config import settings


class PaymentService:
    """Service for handling Razorpay payments"""
    
    def __init__(self):
        self.client = None
        if settings.razorpay_key_id and settings.razorpay_key_secret:
            self.client = razorpay.Client(
                auth=(settings.razorpay_key_id, settings.razorpay_key_secret)
            )
        self.entry_amount = 500  # Legacy per-entry amount in paise
        
        # In-memory payment tracking (for production, use database/Redis)
        self.verified_payments: Dict[str, Dict] = {}
    
    def create_order(
        self,
        phone: str,
        amount: int = None,
        purpose: str = "Train seat exchange entry",
        plan_code: str | None = None,
    ) -> Dict:
        """Create a Razorpay order for payment"""
        if amount is None:
            amount = self.entry_amount

        if self.client is None or not settings.razorpay_key_id:
            return {
                "success": False,
                "message": "Razorpay is not configured."
            }
        
        try:
            order_data = {
                'amount': amount,  # Amount in paise
                'currency': 'INR',
                'payment_capture': 1,  # Auto capture
                'notes': {
                    'phone': phone,
                    'purpose': purpose,
                    'plan_code': plan_code or '',
                }
            }
            
            order = self.client.order.create(data=order_data)
            
            return {
                "success": True,
                "order_id": order['id'],
                "amount": order['amount'],
                "currency": order['currency'],
                "key_id": settings.razorpay_key_id  # Send to frontend for payment
            }
            
        except Exception as e:
            return {
                "success": False,
                "message": "Failed to create payment order",
                "error": str(e)
            }
    
    def verify_payment(self, order_id: str, payment_id: str, signature: str) -> Dict:
        """Verify Razorpay payment signature"""
        try:
            if self.client is None or not settings.razorpay_key_secret:
                return {
                    "success": False,
                    "message": "Razorpay is not configured."
                }

            # Generate signature
            message = f"{order_id}|{payment_id}"
            expected_signature = hmac.new(
                settings.razorpay_key_secret.encode(),
                message.encode(),
                hashlib.sha256
            ).hexdigest()
            
            # Verify signature
            if expected_signature == signature:
                # Fetch payment details
                payment = self.client.payment.fetch(payment_id)
                
                if payment['status'] == 'captured' or payment['status'] == 'authorized':
                    # Store verified payment
                    phone = payment['notes'].get('phone', '')
                    self.verified_payments[payment_id] = {
                        'order_id': order_id,
                        'payment_id': payment_id,
                        'phone': phone,
                        'amount': payment['amount'],
                        'status': payment['status']
                    }
                    
                    return {
                        "success": True,
                        "message": "Payment verified successfully",
                        "payment_id": payment_id,
                        "phone": phone
                    }
                else:
                    return {
                        "success": False,
                        "message": f"Payment not completed. Status: {payment['status']}"
                    }
            else:
                return {
                    "success": False,
                    "message": "Invalid payment signature"
                }
                
        except Exception as e:
            return {
                "success": False,
                "message": "Payment verification failed",
                "error": str(e)
            }
    
    def is_payment_verified(self, payment_id: str, phone: str) -> bool:
        """Check if payment is verified for a phone number"""
        payment_data = self.verified_payments.get(payment_id)
        
        if not payment_data:
            return False
        
        return payment_data['phone'] == phone
    
    def get_payment_details(self, payment_id: str) -> Dict:
        """Get details of a verified payment"""
        return self.verified_payments.get(payment_id)


# Singleton instance
payment_service = PaymentService()
