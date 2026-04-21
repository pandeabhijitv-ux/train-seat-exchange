"""
Proximity Matching for Seat Exchange
Calculates distance between seats and sorts matches by proximity
"""
import re
from typing import List, Dict, Tuple, Optional


class ProximityMatcher:
    """Calculate seat proximity and sort matches"""
    
    # Define typical coach types and their capacities
    COACH_TYPES = {
        'SL': 72,   # Sleeper
        '3A': 64,   # 3-tier AC
        '2A': 48,   # 2-tier AC
        '1A': 24,   # 1st AC
        'CC': 78,   # Chair Car
    }
    
    @staticmethod
    def parse_seat(seat: str) -> Tuple[Optional[int], Optional[str]]:
        """
        Parse seat number into numeric part and berth type
        Examples: "45UB" -> (45, "UB"), "12" -> (12, None)
        """
        match = re.match(r'(\d+)([A-Z]*)', seat.upper().strip())
        if match:
            seat_num = int(match.group(1))
            berth = match.group(2) if match.group(2) else None
            return seat_num, berth
        return None, None
    
    @staticmethod
    def parse_bogie(bogie: str) -> Tuple[Optional[str], Optional[int]]:
        """
        Parse bogie code into type and number
        Examples: "B3" -> ("B", 3), "A2" -> ("A", 2), "S5" -> ("S", 5)
        """
        match = re.match(r'([A-Z]+)(\d+)', bogie.upper().strip())
        if match:
            bogie_type = match.group(1)
            bogie_num = int(match.group(2))
            return bogie_type, bogie_num
        return None, None
    
    @staticmethod
    def calculate_seat_distance(seat1: str, seat2: str) -> int:
        """
        Calculate distance between two seat numbers
        Returns: absolute difference in seat numbers (0 if parsing fails)
        """
        num1, berth1 = ProximityMatcher.parse_seat(seat1)
        num2, berth2 = ProximityMatcher.parse_seat(seat2)
        
        if num1 is None or num2 is None:
            return 999  # Large distance for unparseable seats
        
        # Base distance is seat number difference
        distance = abs(num1 - num2)
        
        # Add penalty if berth types differ (but both have berth types)
        if berth1 and berth2 and berth1 != berth2:
            distance += 2  # Small penalty for different berth
        
        return distance
    
    @staticmethod
    def calculate_bogie_distance(bogie1: str, bogie2: str) -> int:
        """
        Calculate distance between two bogies
        Returns: bogie number difference (0 if same type, large if different type)
        """
        type1, num1 = ProximityMatcher.parse_bogie(bogie1)
        type2, num2 = ProximityMatcher.parse_bogie(bogie2)
        
        if type1 is None or type2 is None:
            return 999
        
        # Different bogie types = farther apart
        if type1 != type2:
            return 100 + abs(num1 - num2)
        
        # Same type, different numbers
        return abs(num1 - num2)
    
    @staticmethod
    def calculate_proximity_score(
        user_current_bogie: str,
        user_current_seat: str,
        user_desired_bogie: str,
        user_desired_seat: str,
        other_current_bogie: str,
        other_current_seat: str,
        other_desired_bogie: str,
        other_desired_seat: str
    ) -> Tuple[int, Dict]:
        """
        Calculate overall proximity score between two exchange requests
        
        Lower score = better match
        
        Returns: (total_score, details_dict)
        """
        # Calculate distances
        # How close is the OTHER person's CURRENT seat to where I WANT to be?
        desired_bogie_dist = ProximityMatcher.calculate_bogie_distance(
            user_desired_bogie, other_current_bogie
        )
        desired_seat_dist = ProximityMatcher.calculate_seat_distance(
            user_desired_seat, other_current_seat
        )
        
        # How close is the OTHER person's DESIRED seat to where I AM now?
        current_bogie_dist = ProximityMatcher.calculate_bogie_distance(
            user_current_bogie, other_desired_bogie
        )
        current_seat_dist = ProximityMatcher.calculate_seat_distance(
            user_current_seat, other_desired_seat
        )
        
        # Total score (weighted)
        # Prioritize: "Can they give me what I want?"
        total_score = (
            desired_bogie_dist * 10 +  # Bogie matters most
            desired_seat_dist * 2 +     # Seat proximity
            current_bogie_dist * 5 +    # Mutual benefit
            current_seat_dist * 1
        )
        
        details = {
            'proximity_score': total_score,
            'desired_bogie_distance': desired_bogie_dist,
            'desired_seat_distance': desired_seat_dist,
            'current_bogie_distance': current_bogie_dist,
            'current_seat_distance': current_seat_dist,
            'is_same_bogie': desired_bogie_dist == 0,
            'is_exact_match': (desired_bogie_dist == 0 and desired_seat_dist == 0),
            'match_quality': ProximityMatcher._get_match_quality(total_score)
        }
        
        return total_score, details
    
    @staticmethod
    def _get_match_quality(score: int) -> str:
        """
        Convert proximity score to quality rating
        """
        if score <= 10:
            return 'excellent'  # 🟢 Excellent match
        elif score <= 30:
            return 'good'       # 🟡 Good match
        elif score <= 100:
            return 'fair'       # 🟠 Fair match
        else:
            return 'poor'       # 🔴 Poor match
    
    @staticmethod
    def sort_by_proximity(
        entries: List[Dict],
        user_current_bogie: str,
        user_current_seat: str,
        user_desired_bogie: str,
        user_desired_seat: str
    ) -> List[Dict]:
        """
        Sort search results by proximity to user's desired seat
        
        Args:
            entries: List of seat exchange entries from database
            user_current_bogie: User's current bogie
            user_current_seat: User's current seat
            user_desired_bogie: User's desired bogie
            user_desired_seat: User's desired seat
        
        Returns:
            Sorted list with proximity_details added to each entry
        """
        results = []
        
        for entry in entries:
            score, details = ProximityMatcher.calculate_proximity_score(
                user_current_bogie,
                user_current_seat,
                user_desired_bogie,
                user_desired_seat,
                entry['current_bogie'],
                entry['current_seat'],
                entry['desired_bogie'],
                entry['desired_seat']
            )
            
            # Add proximity details to entry
            entry_with_proximity = entry.copy()
            entry_with_proximity['proximity_details'] = details
            
            results.append((score, entry_with_proximity))
        
        # Sort by score (ascending - lower is better)
        results.sort(key=lambda x: x[0])
        
        # Return just the entries (without scores)
        return [entry for score, entry in results]
