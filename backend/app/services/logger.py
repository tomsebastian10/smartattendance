import logging
import sys
import json
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger("smart_attendance")

def log_validation_event(event_type: str, details: dict):
    """Structured logging for validation and fraud events."""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "event_type": event_type,
        **details
    }
    logger.info(f"VALIDATION_EVENT: {json.dumps(log_entry)}")

def log_fraud_event(student_id: int, session_id: str, flag: str, details: dict):
    """Structured logging for potential fraud detection."""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "student_id": student_id,
        "session_id": session_id,
        "fraud_flag": flag,
        **details
    }
    logger.warning(f"FRAUD_DETECTED: {json.dumps(log_entry)}")
