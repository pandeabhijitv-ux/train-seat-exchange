"""
PNR Verification Service
Validates PNR status from Indian Railways
"""
import httpx
from typing import Any, Dict, Optional
from config import settings

try:
    import certifi
except ImportError:  # pragma: no cover - optional fallback
    certifi = None


class PNRService:
    def __init__(self):
        self.api_provider = getattr(settings, 'pnr_api_provider', 'mock')
        self.rapidapi_key = getattr(settings, 'rapidapi_key', None)
        self.rapidapi_host = getattr(
            settings,
            'rapidapi_host',
            'pnr-status-indian-railway.p.rapidapi.com',
        )
        self.rapidapi_base_url = getattr(
            settings,
            'rapidapi_base_url',
            f"https://{self.rapidapi_host}",
        )
        self.rapidapi_pnr_path = getattr(
            settings,
            'rapidapi_pnr_path',
            '/pnr-check/{pnr}',
        )
        self.rapidapi_timeout_seconds = getattr(settings, 'rapidapi_timeout_seconds', 10)
        self.rapidapi_tls_verify = getattr(settings, 'rapidapi_tls_verify', True)
        
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
            path = self.rapidapi_pnr_path.format(pnr=pnr)
            url = f"{self.rapidapi_base_url.rstrip('/')}/{path.lstrip('/')}"
            headers = {
                "X-RapidAPI-Key": self.rapidapi_key,
                "X-RapidAPI-Host": self.rapidapi_host
            }
            
            verify_setting: Any
            if self.rapidapi_tls_verify:
                verify_setting = certifi.where() if certifi is not None else True
            else:
                verify_setting = False

            async with httpx.AsyncClient(
                timeout=float(self.rapidapi_timeout_seconds),
                verify=verify_setting,
            ) as client:
                response = await client.get(url, headers=headers)
                
                if response.status_code != 200:
                    return {
                        'success': False,
                        'message': f'Failed to fetch PNR status (HTTP {response.status_code})'
                    }
                
                data = response.json()
                return self._normalize_rapidapi_response(pnr, data)
                    
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

    @staticmethod
    def _first_non_empty(values: list[Any], default: str = '') -> str:
        for value in values:
            if value is None:
                continue
            text = str(value).strip()
            if text:
                return text
        return default

    @staticmethod
    def _is_success_payload(data: Dict[str, Any]) -> bool:
        if 'error' in data and data.get('error'):
            return False

        success = data.get('success')
        if isinstance(success, bool):
            return success

        status_value = str(data.get('status', '')).lower()
        if status_value in {'success', 'ok', 'true'}:
            return True

        payload = data.get('data') if isinstance(data.get('data'), dict) else data
        likely_data = (
            payload.get('trainNumber')
            or payload.get('train_number')
            or payload.get('passengers')
            or payload.get('passenger')
            or payload.get('passengerList')
        )
        return bool(likely_data)

    def _normalize_rapidapi_response(self, pnr: str, data: Dict[str, Any]) -> Dict:
        if not self._is_success_payload(data):
            return {
                'success': False,
                'message': self._first_non_empty(
                    [
                        data.get('message'),
                        data.get('error'),
                        data.get('detail'),
                        data.get('errorMessage'),
                    ],
                    default='Invalid PNR or PNR not found',
                )
            }

        payload = data.get('data') if isinstance(data.get('data'), dict) else data

        passengers = (
            payload.get('passengers')
            or payload.get('passenger')
            or payload.get('passengerList')
            or []
        )
        if isinstance(passengers, dict):
            passengers = [passengers]
        first_passenger = passengers[0] if passengers else {}

        booking_status = self._first_non_empty(
            [
                first_passenger.get('currentStatus'),
                first_passenger.get('current_status'),
                first_passenger.get('bookingStatus'),
                first_passenger.get('booking_status'),
                first_passenger.get('currentStatusDetails'),
            ],
            default='Unknown',
        )

        seat_number = self._first_non_empty(
            [
                first_passenger.get('bookingStatusDetails'),
                first_passenger.get('currentStatusDetails'),
                first_passenger.get('booking_status_details'),
                first_passenger.get('current_status_details'),
                first_passenger.get('berthNo'),
                first_passenger.get('berth_no'),
                first_passenger.get('seat_number'),
            ],
            default='N/A',
        )

        bogie = self._first_non_empty(
            [
                first_passenger.get('bookingCoachId'),
                first_passenger.get('coachPosition'),
                first_passenger.get('coach'),
                first_passenger.get('coach_position'),
                first_passenger.get('currentCoachId'),
            ]
        )

        is_confirmed = booking_status.upper().startswith('CNF') or booking_status.lower() == 'confirmed'

        return {
            'success': True,
            'pnr': pnr,
            'train_number': self._first_non_empty([payload.get('trainNumber'), payload.get('train_number')]),
            'train_name': self._first_non_empty([payload.get('trainName'), payload.get('train_name')]),
            'boarding_station': self._first_non_empty([
                payload.get('from'),
                payload.get('boarding_station'),
                payload.get('boardingPoint'),
                payload.get('sourceStation'),
            ]),
            'destination_station': self._first_non_empty([
                payload.get('to'),
                payload.get('destination_station'),
                payload.get('destinationStation'),
            ]),
            'seat_number': seat_number,
            'status': booking_status,
            'is_confirmed': is_confirmed,
            'passenger_name': self._first_non_empty(
                [first_passenger.get('passengerName'), first_passenger.get('passenger_name')]
            ),
            'date_of_journey': self._first_non_empty([
                payload.get('dateOfJourney'),
                payload.get('date_of_journey'),
            ]),
            'bogie': bogie,
            'class': self._first_non_empty([
                payload.get('class'),
                payload.get('travel_class'),
                payload.get('journeyClass'),
            ]),
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
