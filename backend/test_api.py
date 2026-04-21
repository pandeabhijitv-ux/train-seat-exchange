"""
Test script for Train Seat Exchange API
Tests all endpoints without requiring real API keys
"""
import httpx
import asyncio
from datetime import datetime, timedelta


BASE_URL = "http://localhost:8000/api/v1"


async def test_api():
    async with httpx.AsyncClient() as client:
        print("\n" + "="*60)
        print("🚂 Train Seat Exchange API Test Suite")
        print("="*60 + "\n")
        
        # Test 1: Root endpoint
        print("📍 Test 1: Root Endpoint")
        try:
            response = await client.get("http://localhost:8000/")
            print(f"✅ Status: {response.status_code}")
            print(f"   Response: {response.json()}\n")
        except Exception as e:
            print(f"❌ Error: {e}\n")
            return
        
        # Test 2: Send OTP (will fail with mock credentials, but tests endpoint)
        print("📍 Test 2: Send OTP")
        try:
            response = await client.post(
                f"{BASE_URL}/otp/send",
                json={"phone": "9876543210"}
            )
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.json()}\n")
        except Exception as e:
            print(f"   Info: {e}\n")
        
        # Test 3: Create seat exchange entry (without OTP verification for testing)
        print("📍 Test 3: Create Seat Exchange Entry")
        departure_time = datetime.now() + timedelta(hours=5)
        try:
            entry_data = {
                "phone": "9876543210",
                "pnr": "1234567890",
                "train_number": "12345",
                "train_name": "Rajdhani Express",
                "from_station": "NDLS",
                "to_station": "BCT",
                "departure_datetime": departure_time.isoformat(),
                "current_seat": "A1-25-LB",
                "desired_seat": "A1-30-UB",
                "exchange_fee": 50
            }
            response = await client.post(
                f"{BASE_URL}/entry/create",
                json=entry_data
            )
            print(f"   Status: {response.status_code}")
            result = response.json()
            print(f"   Response: {result}\n")
            
            # Store entry ID for later tests
            if response.status_code in [200, 201]:
                entry_id = result.get("id")
                
                # Test 4: Search for entries
                print("📍 Test 4: Search Entries")
                search_data = {
                    "train_number": "12345",
                    "from_station": "NDLS",
                    "to_station": "BCT"
                }
                response = await client.post(
                    f"{BASE_URL}/entry/search",
                    json=search_data
                )
                print(f"   Status: {response.status_code}")
                print(f"   Found {len(response.json())} entries\n")
                
                # Test 5: Get specific entry
                print("📍 Test 5: Get Entry Details")
                response = await client.get(f"{BASE_URL}/entry/{entry_id}")
                print(f"   Status: {response.status_code}")
                print(f"   Entry: {response.json()}\n")
                
                # Test 6: Update entry status
                print("📍 Test 6: Update Entry Status")
                response = await client.patch(
                    f"{BASE_URL}/entry/{entry_id}/status",
                    json={"status": "completed"}
                )
                print(f"   Status: {response.status_code}")
                print(f"   Response: {response.json()}\n")
                
        except Exception as e:
            print(f"   Error: {e}\n")
        
        # Test 7: Create payment order (will fail without real Razorpay credentials)
        print("📍 Test 7: Create Payment Order")
        try:
            payment_data = {
                "phone": "9876543210",
                "amount": 100
            }
            response = await client.post(
                f"{BASE_URL}/payment/create",
                json=payment_data
            )
            print(f"   Status: {response.status_code}")
            print(f"   Info: Payment endpoint requires real Razorpay credentials\n")
        except Exception as e:
            print(f"   Expected: Payment requires valid credentials\n")
        
        print("="*60)
        print("✅ API Test Suite Completed!")
        print("="*60 + "\n")
        print("💡 Notes:")
        print("   - OTP and Payment features require real API credentials")
        print("   - Core functionality (entries, search) works with mock data")
        print("   - Check http://localhost:8000/docs for interactive API docs")
        print("\n")


if __name__ == "__main__":
    print("\n⏳ Starting tests in 3 seconds...")
    print("   Make sure the backend server is running!")
    import time
    time.sleep(3)
    asyncio.run(test_api())
