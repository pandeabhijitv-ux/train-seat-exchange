# PNR Verification - API Options & Costs

## Overview
PNR verification validates Indian Railways booking details including train number, seat status, and passenger information.

## API Options

### 1. RapidAPI - Indian Railway PNR Status APIs

**Recommended Providers:**

#### Option A: Railway API by Indian Railway API
- **URL:** https://rapidapi.com/indian-railway-api/api/indian-railway
- **Cost:** 
  - Free tier: 100 requests/month
  - Basic: $5/month for 10,000 requests ($0.0005/request)
  - Pro: $15/month for 100,000 requests ($0.00015/request)
- **Features:** Real-time PNR status, train info, seat availability
- **Response Time:** < 2 seconds

#### Option B: PNR Status by Aarav Srivastava
- **URL:** https://rapidapi.com/aarav_srivastava01/api/pnr-status-indian-railway
- **Cost:**
  - Free: 50 requests/month
  - Basic: $3.99/month for 5,000 requests
  - Pro: $9.99/month for 50,000 requests
- **Features:** PNR status, passenger details, booking status

### 2. RailwayAPI.com
- **URL:** https://railwayapi.com
- **Cost:** 
  - Starter: ₹299/month (1,000 requests)
  - Growth: ₹999/month (10,000 requests)
  - Business: ₹2,999/month (100,000 requests)
- **Features:** Official IRCTC data, 99.9% uptime

### 3. ConfirmTkt API
- **URL:** https://www.confirmtkt.com/api
- **Cost:** Contact for pricing (typically ₹0.10-0.50 per request)
- **Features:** PNR, train running status, seat availability

### 4. Mock Mode (Free - For Testing)
- **Cost:** FREE
- **Use Case:** Development and testing only
- **Limitations:** Returns fake data, not production-ready

## Cost Comparison

| Provider | Free Tier | Paid Plans | Cost per Request | Best For |
|----------|-----------|------------|------------------|----------|
| RapidAPI (Railway) | 100/month | From $5/month | $0.0005 | High volume |
| RapidAPI (PNR Status) | 50/month | From $3.99/month | $0.0008 | Budget friendly |
| RailwayAPI.com | No | From ₹299/month | ₹0.30 | Indian businesses |
| ConfirmTkt | No | Custom | ₹0.10-0.50 | Enterprise |
| Mock Mode | Unlimited | Free | Free | Testing only |

## Setup Instructions

### Using RapidAPI (Recommended)

1. **Sign up for RapidAPI:**
   - Go to https://rapidapi.com
   - Create free account
   - Subscribe to "Indian Railway PNR Status" API

2. **Get API Key:**
   - Go to your API dashboard
   - Copy your "X-RapidAPI-Key"

3. **Update Configuration:**
   ```env
   # In backend/.env
   PNR_API_PROVIDER=rapidapi
   RAPIDAPI_KEY=your_actual_key_here
   RAPIDAPI_HOST=pnr-status-indian-railway.p.rapidapi.com
   ```

4. **Test the API:**
   ```powershell
   # Use Swagger UI at http://localhost:8000/docs
   # Or test with PowerShell:
   Invoke-RestMethod -Uri "http://localhost:8000/api/v1/pnr/verify" -Method Post -Body '{"pnr":"1234567890"}' -ContentType "application/json"
   ```

## Estimated Monthly Costs

Based on usage patterns:

| Users | Requests/Month | Recommended Plan | Monthly Cost |
|-------|----------------|------------------|--------------|
| 100 | ~500 | RapidAPI Free | $0 |
| 1,000 | ~5,000 | RapidAPI Basic | $5 |
| 10,000 | ~50,000 | RapidAPI Pro | $15 |
| 50,000+ | 250,000+ | RailwayAPI Business | ₹2,999 (~$36) |

## Sample API Response

```json
{
  "success": true,
  "pnr": "1234567890",
  "train_number": "12345",
  "train_name": "Rajdhani Express",
  "boarding_station": "NDLS",
  "destination_station": "BCT",
  "seat_number": "A1-25-LB",
  "status": "CNF",
  "is_confirmed": true,
  "passenger_name": "John Doe",
  "date_of_journey": "2025-12-25",
  "bogie": "A1",
  "class": "3A"
}
```

## Integration Benefits

✅ **Prevents Fraud:** Verifies actual IRCTC bookings
✅ **Auto-Fill:** Pre-fills train details from PNR
✅ **Confirmed Seats Only:** Ensures only confirmed tickets are listed
✅ **Better UX:** Users don't need to enter train details manually
✅ **Trust:** Builds confidence in platform authenticity

## Recommendation

**For Production:** Start with **RapidAPI free tier** (100 requests/month)
- Zero cost to start
- Upgrade as you grow
- $5/month covers 10,000 verifications
- Real IRCTC data

**For Development:** Use **mock mode**
- Free unlimited testing
- No API keys needed
- Switch to real API when ready

## Current Configuration

Your app is set to **mock mode** for testing. To enable real PNR verification:
1. Get RapidAPI key (free tier available)
2. Update `.env` file with your key
3. Change `PNR_API_PROVIDER=rapidapi`
4. Restart the server
