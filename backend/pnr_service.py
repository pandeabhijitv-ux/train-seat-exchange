"""
PNR Verification Service
Validates PNR status from Indian Railways
"""
import httpx
from typing import Dict, Optional
from config import settings


class PNRService:
    def __init__(self):
        self.api_provider = getattr(settings, 'pnr_api_provider', 'rapidapi')
        self.rapidapi_key = getattr(settings, 'rapidapi_key', None)
        self.rapidapi_host = getattr(settings, 'rapidapi_host', 'pnr-status-indian-railway.p.rapidapi.com')
        
    async def verify_pnr(self, pnr: str) -> Dict:
        """
        Verify PNR status and return booking details
        
        Returns:
        {
            'success': bool,
            'pnr': str,
            'train_number': str,
            'train_name': str,
            'boarding_station': str,
            'destination_station': str,
            'seat_number': str,
            'status': str,  # CNF, RAC, WL
            'is_confirmed': bool,
            'passenger_name': str,
            'date_of_journey': str
        }
        """
        
        if self.api_provider == 'rapidapi':
            return await self._verify_via_rapidapi(pnr)
        elif self.api_provider == 'mock':
            return self._mock_verification(pnr)
        else:
            return {
                'success': False,
                'message': 'No PNR API provider configured'
            }
    
    async def _verify_via_rapidapi(self, pnr: str) -> Dict:
        """Verify PNR using RapidAPI"""
        if not self.rapidapi_key:
            return {
                'success': False,
                'message': 'RapidAPI key not configured'
            }
        
        try:
            url = f"https://{self.rapidapi_host}/pnr-check/{pnr}"
            headers = {
                "X-RapidAPI-Key": self.rapidapi_key,
                "X-RapidAPI-Host": self.rapidapi_host
            }
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, headers=headers)
                
                if response.status_code != 200:
                    return {
                        'success': False,
                        'message': 'Failed to fetch PNR status'
                    }
                
                data = response.json()
                
                # Parse response based on API structure
                # Note: Actual structure may vary by provider
                if data.get('success') or data.get('status') == 'success':
                    passengers = data.get('passengers', [])
                    first_passenger = passengers[0] if passengers else {}
                    
                    booking_status = first_passenger.get('bookingStatus', 'Unknown')
                    is_confirmed = booking_status.startswith('CNF') or booking_status == 'Confirmed'
                    
                    return {
                        'success': True,
                        'pnr': pnr,
                        'train_number': data.get('trainNumber', ''),
                        'train_name': data.get('trainName', ''),
                        'boarding_station': data.get('from', ''),
                        'destination_station': data.get('to', ''),
                        'seat_number': first_passenger.get('bookingStatusDetails', 'N/A'),
                        'status': booking_status,
                        'is_confirmed': is_confirmed,
                        'passenger_name': first_passenger.get('passengerName', ''),
                        'date_of_journey': data.get('dateOfJourney', ''),
                        'bogie': first_passenger.get('bookingCoachId', ''),
                        'class': data.get('class', '')
                    }
                else:
                    return {
                        'success': False,
                        'message': data.get('message', 'Invalid PNR or PNR not found')
                    }
                    
        except httpx.TimeoutException:
            return {
                'success': False,
                'message': 'PNR verification timeout'
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'PNR verification error: {str(e)}'
            }
    
    def _mock_verification(self, pnr: str) -> Dict:
        """Mock PNR verification for testing"""
        # Return mock data based on PNR pattern
        if len(pnr) != 10 or not pnr.isdigit():
            return {
                'success': False,
                'message': 'Invalid PNR format. PNR must be 10 digits'
            }
        
        # Mock confirmed ticket
        return {
            'success': True,
            'pnr': pnr,
            'train_number': '12345',
            'train_name': 'Rajdhani Express',
            'boarding_station': 'NDLS',
            'destination_station': 'BCT',
            'seat_number': 'A1-25-LB',
            'status': 'CNF',
            'is_confirmed': True,
            'passenger_name': 'Test Passenger',
            'date_of_journey': '2025-12-25',
            'bogie': 'A1',
            'class': '3A'
        }


# Singleton instance
pnr_service = PNRService()
