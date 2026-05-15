import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/ble_service.dart';
import '../../services/gps_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _bleService = BleService();
  final _gpsService = GpsService();
  final _apiService = ApiService();
  
  bool _isVerifying = false;
  String _statusMessage = "Ready to Scan";
  double _progress = 0.0;

  void _startAttendanceFlow(String qrToken) async {
    setState(() {
      _isVerifying = true;
      _statusMessage = "Validating Location...";
      _progress = 0.3;
    });

    try {
      final decoded = jsonDecode(qrToken);
      final sessionToken = decoded['session_token'];
      final qrSecret = decoded['qr_token'];

      // 1. Get GPS
      final position = await _gpsService.getCurrentLocation();
      
      setState(() {
        _statusMessage = "Scanning for Beacon...";
        _progress = 0.6;
      });

      // 2. Scan BLE (Simulated for MVP)
      int rssi = -65; // Simulated strong signal
      String teacherUuid = "00000000-0000-0000-0000-000000000000"; // Placeholder

      setState(() {
        _statusMessage = "Submitting to Server...";
        _progress = 0.9;
      });

      // 3. Submit to Backend
      final result = await _apiService.verifyAttendance(
        sessionToken: sessionToken,
        qrToken: qrSecret,
        lat: position.latitude,
        long: position.longitude,
        rssi: rssi,
        teacherUuid: teacherUuid,
      );
      
      setState(() {
        _statusMessage = "Attendance: ${result['status']}";
        _progress = 1.0;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Your attendance has been recorded."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Scan Attendance",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              _buildStatusCard(),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && !_isVerifying) {
                          final code = barcodes.first.rawValue;
                          if (code != null) {
                            _startAttendanceFlow(code);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Point your camera at the Teacher's QR Code",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _statusMessage,
            style: GoogleFonts.inter(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[100],
              color: const Color(0xFF1E3C72),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
