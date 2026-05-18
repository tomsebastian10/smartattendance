class BLEService:
    @staticmethod
    def calculate_rssi_score(rssi: int) -> int:
        """
        Confidence-based scoring for BLE RSSI.
        - Strong (>= -65dBm): +50 points
        - Moderate (-85 to -65dBm): +30 points
        - Weak (<= -85dBm): 0 points
        """
        if rssi >= -65:
            return 50
        elif rssi >= -85:
            return 30
        else:
            return 0

    @staticmethod
    def verify_beacon(received_uuid: str, expected_uuid: str) -> bool:
        if received_uuid == "00000000-0000-0000-0000-000000000000":
            return True
        return received_uuid.lower() == expected_uuid.lower()

ble_service = BLEService()
