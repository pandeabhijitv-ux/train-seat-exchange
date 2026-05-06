from fastapi import APIRouter, HTTPException, Request, status
from models import (
    PhoneVerifyRequest, OTPVerifyRequest, SeatExchangeEntry, SearchRequest,
    EntryResponse, UserRegisterRequest, UserProfileResponse,
    SubscriptionOrderRequest, SubscriptionVerifyRequest, PlaySubscriptionVerifyRequest,
)
from otp_service import otp_service
from firebase_auth_service import firebase_auth_service
from payment_service import payment_service
from subscription_service import subscription_service
from google_play_billing_service import google_play_billing_service
from pnr_service import pnr_service
from database import db
from user_limits import user_limits
from user_registry import user_registry
from proximity_matcher import ProximityMatcher
from typing import List
from pydantic import BaseModel

router = APIRouter()


def _get_bearer_token(request: Request) -> str | None:
    authorization = request.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        return None
    return authorization[7:].strip() or None


def _get_authenticated_phone(request: Request, expected_phone: str | None = None) -> str | None:
    token = _get_bearer_token(request)
    if not token:
        return None

    try:
        verified = firebase_auth_service.verify_id_token(token, expected_phone)
        return verified["phone"]
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase authentication token: {str(exc)}",
        ) from exc


def _mask_phone(phone: str) -> str:
    if len(phone) < 5:
        return "XXXXX"
    return f"{phone[:5]}XXXXX"


def _enforce_active_subscription(phone: str):
    if subscription_service.is_active(phone):
        return

    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail=(
            "An active subscription is required for this feature. "
            "Choose Monthly (₹125), Quarterly (₹275), or Yearly (₹950)."
        ),
    )


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


@router.post("/user/register", response_model=dict)
async def register_user(request: UserRegisterRequest, raw_request: Request):
    """Register or refresh a verified user profile"""
    authenticated_phone = _get_authenticated_phone(raw_request, request.phone)

    if authenticated_phone != request.phone and not otp_service.is_phone_verified(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Phone number must be Firebase-authenticated or OTP verified before registration."
        )

    user = user_registry.register_user(request.phone, request.name)
    return {
        "success": True,
        "message": "Registration completed successfully",
        "user": user,
    }


@router.get("/user/profile/{phone}", response_model=UserProfileResponse)
async def get_user_profile(phone: str, raw_request: Request):
    """Fetch a registered user profile"""
    authenticated_phone = _get_authenticated_phone(raw_request)
    if authenticated_phone and authenticated_phone != phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authenticated phone number does not match requested profile."
        )

    profile = user_registry.get_user(phone)
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    return profile


# ============== User Limits Endpoint ==============

@router.get("/user/limits/{phone}")
async def get_user_limits(phone: str, raw_request: Request):
    """Get user entry limits"""
    if len(phone) != 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number format"
        )

    authenticated_phone = _get_authenticated_phone(raw_request)
    if authenticated_phone and authenticated_phone != phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authenticated phone number does not match requested user."
        )
    
    total_entries = user_limits.get_user_entry_count(phone)
    remaining = user_limits.get_remaining_entries(phone)
    subscription = subscription_service.get_subscription(phone)
    
    return {
        "success": True,
        "phone": phone,
        "total_entries": total_entries,
        "max_entries": user_limits.MAX_ENTRIES_PER_USER,
        "remaining_entries": remaining,
        "can_create_more": remaining > 0,
        "subscription": subscription,
    }


# ============== Subscription Endpoints ==============

@router.get("/subscription/plans")
async def get_subscription_plans():
    """Get available subscription plans."""
    return {
        "success": True,
        "plans": subscription_service.get_plans(),
    }


@router.get("/subscription/status/{phone}")
async def get_subscription_status(phone: str, raw_request: Request):
    """Get a user's current subscription status."""
    if len(phone) != 10 or not phone.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number format"
        )

    authenticated_phone = _get_authenticated_phone(raw_request, phone)
    if authenticated_phone != phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase authentication is required to view subscription status."
        )

    subscription = subscription_service.get_subscription(phone)
    return {
        "success": True,
        "phone": phone,
        "is_active": bool(subscription and subscription.get("is_active")),
        "subscription": subscription,
    }


@router.post("/subscription/order")
async def create_subscription_order(request: SubscriptionOrderRequest, raw_request: Request):
    """Create Razorpay order for subscription purchase."""
    authenticated_phone = _get_authenticated_phone(raw_request, request.phone)
    if authenticated_phone != request.phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase authentication is required to create subscription orders."
        )

    if not user_registry.is_registered(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Complete registration before purchasing a subscription."
        )

    plan = subscription_service.get_plan(request.plan_code)
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid subscription plan selected."
        )

    amount_paise = plan["price_inr"] * 100
    order_result = payment_service.create_order(
        phone=request.phone,
        amount=amount_paise,
        purpose=f"Subscription purchase: {plan['name']}",
        plan_code=plan["code"],
    )

    if not order_result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=order_result.get("message", "Unable to create subscription order."),
        )

    subscription_service.save_pending_order(
        order_id=order_result["order_id"],
        phone=request.phone,
        plan_code=plan["code"],
        amount_paid=amount_paise,
    )

    return {
        "success": True,
        "order": order_result,
        "plan": {
            "code": plan["code"],
            "name": plan["name"],
            "price_inr": plan["price_inr"],
            "duration_days": plan["duration_days"],
        },
    }


@router.post("/subscription/verify")
async def verify_subscription_payment(request: SubscriptionVerifyRequest, raw_request: Request):
    """Verify Razorpay payment and activate subscription."""
    authenticated_phone = _get_authenticated_phone(raw_request, request.phone)
    if authenticated_phone != request.phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase authentication is required to verify subscription payment."
        )

    pending_order = subscription_service.get_pending_order(request.order_id)
    if not pending_order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subscription order not found."
        )

    if pending_order.get("consumed") == 1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This subscription order is already consumed."
        )

    if pending_order["phone"] != request.phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Subscription order does not belong to this phone number."
        )

    verify_result = payment_service.verify_payment(
        order_id=request.order_id,
        payment_id=request.payment_id,
        signature=request.signature,
    )

    if not verify_result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=verify_result.get("message", "Payment verification failed."),
        )

    activated = subscription_service.activate_subscription(
        phone=request.phone,
        plan_code=pending_order["plan_code"],
        amount_paid=pending_order["amount_paid"],
        order_id=request.order_id,
        payment_id=request.payment_id,
    )
    subscription_service.consume_pending_order(request.order_id)

    return {
        "success": True,
        "message": "Subscription activated successfully.",
        "subscription": activated,
    }


@router.post("/subscription/play/verify")
async def verify_google_play_subscription(
    request: PlaySubscriptionVerifyRequest,
    raw_request: Request,
):
    """Verify Google Play Billing purchase token and activate subscription."""
    authenticated_phone = _get_authenticated_phone(raw_request, request.phone)
    if authenticated_phone != request.phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase authentication is required to verify Google Play purchases.",
        )

    if not user_registry.is_registered(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Complete registration before activating subscription.",
        )

    plan = subscription_service.get_plan_by_product_id(request.product_id)
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported product_id. Configure monthly_125, quarterly_275, or yearly_950.",
        )

    try:
        verify_result = await google_play_billing_service.verify_subscription_purchase(
            product_id=request.product_id,
            purchase_token=request.purchase_token,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Google Play verification failed: {str(exc)}",
        ) from exc

    if not verify_result.get("is_active"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Purchase token is valid but subscription is not active. "
                f"State: {verify_result.get('state', 'UNKNOWN')}"
            ),
        )

    activated = subscription_service.activate_subscription(
        phone=request.phone,
        plan_code=plan["code"],
        amount_paid=plan["price_inr"] * 100,
        order_id=verify_result.get("latest_order_id") or f"play:{request.product_id}",
        payment_id=request.purchase_id or request.purchase_token,
    )

    return {
        "success": True,
        "message": "Google Play subscription verified and activated.",
        "subscription": activated,
        "google_play_state": verify_result.get("state"),
        "google_play_expiry": verify_result.get("expiry_time"),
    }


# ============== Seat Exchange Endpoints ==============

@router.post("/entry/create", response_model=dict)
async def create_entry(request: SeatExchangeEntry, raw_request: Request):
    """Create seat exchange entry"""

    authenticated_phone = _get_authenticated_phone(raw_request)

    if authenticated_phone:
        if authenticated_phone != request.phone:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Authenticated phone number does not match entry phone number."
            )
    elif not otp_service.is_phone_verified(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Phone number must be authenticated before creating an entry."
        )

    if not user_registry.is_registered(request.phone):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Complete phone verification and registration before creating an entry."
        )

    _enforce_active_subscription(request.phone)
    
    # Check for duplicate entry (one entry per train per phone)
    if db.check_duplicate_entry(request.phone, request.train_number, request.train_date):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have an entry for this train. One entry per person per train allowed."
        )
    
    try:
        entry_data = request.dict()
        entry_id = db.create_entry(entry_data)
        
        # Track entry count for analytics (not enforced server-side)
        new_count = user_limits.increment_entry_count(request.phone)
        
        can_view_contact = user_registry.is_registered(request.phone)
        matches = db.find_exact_matches(entry_data)

        for match in matches:
            match["contact_visible"] = can_view_contact
            if not can_view_contact:
                match["phone"] = _mask_phone(match["phone"])

        return {
            "success": True,
            "message": "Entry created successfully",
            "entry_id": entry_id,
            "total_entries": new_count,
            "note": "Your entry is now visible to other users.",
            "match_count": len(matches),
            "matches": matches,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create entry: {str(e)}"
        )


@router.post("/entry/search", response_model=List[EntryResponse])
async def search_entries(request: SearchRequest, raw_request: Request):
    """Search for seat exchange entries with optional proximity sorting"""
    try:
        authenticated_phone = _get_authenticated_phone(raw_request)
        can_view_contact = bool(
            request.requester_phone and
            authenticated_phone == request.requester_phone and
            user_registry.is_registered(request.requester_phone)
        )

        if request.requester_phone:
            _enforce_active_subscription(request.requester_phone)

        entries = db.search_entries(
            request.train_number,
            request.train_date,
            request.bogie,
            request.requester_phone,
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

        for entry in entries:
            entry["contact_visible"] = can_view_contact
            if not can_view_contact:
                entry["phone"] = _mask_phone(entry["phone"])
        
        return entries
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )


@router.get("/entry/my-active/{phone}", response_model=dict)
async def get_my_active_entries(phone: str, raw_request: Request):
    """Get a user's currently active entries and reciprocal match previews."""
    if len(phone) != 10 or not phone.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number format"
        )

    authenticated_phone = _get_authenticated_phone(raw_request, phone)
    if authenticated_phone != phone:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Firebase authentication is required to view your active entries."
        )

    can_view_contact = user_registry.is_registered(phone)
    _enforce_active_subscription(phone)
    entries = db.get_user_entries(phone)

    enriched_entries = []
    for entry in entries:
        matches = db.find_exact_matches(entry)
        for match in matches:
            match["contact_visible"] = can_view_contact
            if not can_view_contact:
                match["phone"] = _mask_phone(match["phone"])

        entry["has_match"] = len(matches) > 0
        entry["match_count"] = len(matches)
        entry["match_preview"] = matches[:3]
        enriched_entries.append(entry)

    return {
        "success": True,
        "phone": phone,
        "entry_count": len(enriched_entries),
        "entries": enriched_entries,
    }


# ============== Health Check ==============

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Train Seat Exchange API"
    }
