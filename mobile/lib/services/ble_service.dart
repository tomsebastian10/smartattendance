import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> startScanning({
    required String targetUuid,
    required Function(int rssi) onFound,
  }) async {
    // Check if Bluetooth is ON
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is off');
    }

    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Check if the service UUID matches (or other identifier)
        if (r.advertisementData.serviceUuids.contains(Guid(targetUuid))) {
          onFound(r.rssi);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });
  }

  void stopScanning() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }
}
