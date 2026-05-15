import redis
import os
import json
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))

class RedisService:
    def __init__(self):
        self.client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            decode_responses=True
        )

    def set_session_nonce(self, session_id: str, nonce: str, ttl: int = 20):
        """Sets a short-lived nonce for a specific session's QR code."""
        key = f"nonce:{session_id}"
        self.client.set(key, nonce, ex=ttl)

    def get_session_nonce(self, session_id: str) -> Optional[str]:
        key = f"nonce:{session_id}"
        return self.client.get(key)

    def mark_attendance_processed(self, session_id: str, student_id: int, ttl: int = 3600):
        """Prevents duplicate processing in Redis for the current session."""
        key = f"processed:{session_id}:{student_id}"
        self.client.set(key, "1", ex=ttl)

    def is_attendance_processed(self, session_id: str, student_id: int) -> bool:
        key = f"processed:{session_id}:{student_id}"
        return self.client.exists(key) > 0

redis_service = RedisService()
