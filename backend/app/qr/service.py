import hmac
import hashlib
import time
import base64
from typing import Tuple

class QRService:
    @staticmethod
    def generate_qr_token(secret: str, interval: int = 20) -> Tuple[str, int]:
        """Generates a time-based token using HMAC-SHA256."""
        # Current time window
        timestamp = int(time.time() // interval)
        message = f"{timestamp}".encode()
        key = secret.encode()
        
        h = hmac.new(key, message, hashlib.sha256)
        token = base64.urlsafe_b64encode(h.digest()).decode().strip("=")
        
        return token[:12], timestamp # Return a shorter 12-char token for the QR

    @staticmethod
    def verify_qr_token(secret: str, token: str, interval: int = 20) -> bool:
        """Verifies token against current and previous time window (drift allowance)."""
        current_time = int(time.time())
        # Check current and previous window to handle edge-of-window scans
        for offset in [0, -1]:
            expected_token, _ = QRService.generate_qr_token(secret, interval)
            # Recalculate with offset
            timestamp = (current_time // interval) + offset
            message = f"{timestamp}".encode()
            h = hmac.new(secret.encode(), message, hashlib.sha256)
            calc_token = base64.urlsafe_b64encode(h.digest()).decode().strip("=")[:12]
            
            if hmac.compare_digest(calc_token, token):
                return True
        return False

qr_service = QRService()
