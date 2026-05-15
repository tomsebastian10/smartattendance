from abc import ABC, abstractmethod
from typing import Dict, Any, Tuple
from ..gps.service import gps_service
from ..ble.service import ble_service
from ..qr.service import qr_service

class BaseValidator(ABC):
    @abstractmethod
    def validate(self, data: Any, context: Dict[str, Any]) -> Tuple[int, Dict[str, Any]]:
        """Returns (score, metadata)."""
        pass

class QRValidator(BaseValidator):
    def validate(self, token: str, context: Dict[str, Any]) -> Tuple[int, Dict[str, Any]]:
        secret = context.get("qr_secret")
        is_valid = qr_service.verify_qr_token(secret, token)
        score = 20 if is_valid else 0
        return score, {"valid": is_valid}

class GPSValidator(BaseValidator):
    def validate(self, data: Dict[str, Any], context: Dict[str, Any]) -> Tuple[int, Dict[str, Any]]:
        if not data:
            return 0, {"error": "No GPS data"}
        
        target_lat = context.get("lat")
        target_long = context.get("long")
        radius = context.get("radius", 200)
        
        distance = gps_service.calculate_distance(data["lat"], data["long"], target_lat, target_long)
        is_inside = distance <= radius
        score = 20 if is_inside else 0
        
        return score, {"distance": round(distance, 2), "is_inside": is_inside}

class BLEValidator(BaseValidator):
    def validate(self, data: Dict[str, Any], context: Dict[str, Any]) -> Tuple[int, Dict[str, Any]]:
        if not data:
            return 0, {"error": "No BLE data"}
        
        expected_uuid = context.get("ble_uuid")
        if not ble_service.verify_beacon(data["teacher_uuid"], expected_uuid):
            return 0, {"error": "Incorrect Beacon UUID"}
        
        rssi = data["rssi"]
        score = ble_service.calculate_rssi_score(rssi)
        
        return score, {"rssi": rssi}

class ValidationEngine:
    def __init__(self):
        self.validators = {
            "qr": QRValidator(),
            "gps": GPSValidator(),
            "ble": BLEValidator()
        }

    def process(self, request_data: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
        results = {}
        total_score = 0
        
        for key, validator in self.validators.items():
            score, metadata = validator.validate(request_data.get(f"{key}_data"), context)
            results[key] = {"score": score, "metadata": metadata}
            total_score += score
            
        # Add default device trust score (+10) for MVP
        total_score += 10
        results["device"] = {"score": 10, "metadata": {"trusted": True}}
        
        return {
            "total_score": total_score,
            "breakdown": results
        }

validation_engine = ValidationEngine()
