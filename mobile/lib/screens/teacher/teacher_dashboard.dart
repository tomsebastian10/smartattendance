import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import '../../services/api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _currentClass;
  Map<String, dynamic>? _activeSession;
  List<dynamic> _roster = [];
  Timer? _refreshTimer;
  String _qrData = "";

  @override
  void initState() {
    super.initState();
    _checkCurrentClass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCurrentClass() async {
    try {
      final slot = await _apiService.getCurrentClass();
      setState(() {
        _currentClass = slot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startSession() async {
    if (_currentClass == null) return;
    
    setState(() => _isLoading = true);
    try {
      final session = await _apiService.startSession(
        classroomId: 1, // Placeholder
        subjectId: _currentClass!['subject_id'] ?? 1,
        durationMins: 60,
      );
      setState(() {
        _activeSession = session;
        _isLoading = false;
        final qrPayload = {
          "session_token": session['session_token'],
          "qr_token": session['qr_secret']
        };
        _qrData = jsonEncode(qrPayload);
      });
      _startRosterUpdates();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _startRosterUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_activeSession == null) return;
      try {
        final roster = await _apiService.getSessionRoster(_activeSession!['id']);
        setState(() => _roster = roster);
      } catch (e) {
        debugPrint("Roster update failed: $e");
      }
    });
  }

  Future<void> _markManual(int studentId) async {
    try {
      await _apiService.markStudentPresent(_activeSession!['id'], studentId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked present manually")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Future<void> _endSession() async {
    try {
      await _apiService.endSession(_activeSession!['id']);
      _refreshTimer?.cancel();
      setState(() {
        _activeSession = null;
        _roster = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session ended. Absent records created.")));
      _checkCurrentClass();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Teacher Dashboard", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _activeSession != null ? _buildActiveSessionView() : _buildIdleView(),
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              child: FaIcon(FontAwesomeIcons.chalkboardUser, size: 50, color: const Color(0xFF1E3C72).withOpacity(0.5)),
            ),
            const SizedBox(height: 32),
            if (_currentClass != null) ...[
              Text("Scheduled Now", style: GoogleFonts.inter(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Text(_currentClass!['subject_name'] ?? "Class", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_currentClass!['subject_code'] ?? "", style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startSession,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text("Start Attendance Session", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              Text("No classes scheduled right now", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Check your timetable for upcoming sessions", style: GoogleFonts.inter(color: Colors.grey)),
              const SizedBox(height: 40),
              // Optional manual start button
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionView() {
    return Column(
      children: [
        _buildQrHeader(),
        Expanded(child: _buildRosterList()),
        _buildFooterActions(),
      ],
    );
  }

  Widget _buildQrHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          QrImageView(data: _qrData, size: 200, version: QrVersions.auto, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E3C72))),
          const SizedBox(height: 16),
          Text("Scan for Attendance", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("Live QR Security Active", style: GoogleFonts.inter(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRosterList() {
    final presentCount = _roster.where((s) => s['status'] == 'PRESENT').length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Live Student Roster", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text("$presentCount / ${_roster.length} Present", style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _roster.length,
            itemBuilder: (ctx, idx) {
              final student = _roster[idx];
              final bool isPresent = student['status'] == 'PRESENT';
              return _studentTile(student, isPresent);
            },
          ),
        ),
      ],
    );
  }

  Widget _studentTile(dynamic student, bool isPresent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPresent ? Colors.green.withOpacity(0.1) : Colors.grey[100],
            child: FaIcon(isPresent ? FontAwesomeIcons.check : FontAwesomeIcons.user, size: 14, color: isPresent ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(isPresent ? "Marked Present" : "Awaiting Scan...", style: GoogleFonts.inter(color: isPresent ? Colors.green : Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (!isPresent)
            IconButton(
              onPressed: () => _markManual(student['student_id']),
              icon: const FaIcon(FontAwesomeIcons.userPen, size: 18, color: Color(0xFF1E3C72)),
              tooltip: "Mark Manual",
            ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _endSession,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text("End Session", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
