import math

class GPSService:
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculates the Haversine distance between two points in meters."""
        R = 6371000  # Radius of the Earth in meters
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = math.sin(delta_phi / 2)**2 + \
            math.cos(phi1) * math.cos(phi2) * \
            math.sin(delta_lambda / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    @staticmethod
    def is_within_geofence(user_lat: float, user_long: float, target_lat: float, target_long: float, radius: int) -> bool:
        distance = GPSService.calculate_distance(user_lat, user_long, target_lat, target_long)
        return distance <= radius

gps_service = GPSService()
