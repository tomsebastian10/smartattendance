import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/gps_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/constants.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final ApiService _apiService = ApiService();
  final GpsService _gpsService = GpsService();
  bool _isLoading = true;
  Map<String, dynamic>? _currentClass;
  Map<String, dynamic>? _activeSession;
  List<dynamic> _roster = [];
  List<dynamic> _announcements = [];
  Map<String, dynamic>? _nextClass;
  List<dynamic> _history = [];
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
      final anns = await _apiService.getAnnouncements();
      final active = await _apiService.getActiveSession();
      final timetable = await _apiService.getFacultyTimetable();
      final hist = await _apiService.getFacultySessionHistory();
      
      Map<String, dynamic>? next;
      if (slot == null && timetable.isNotEmpty) {
        final now = DateTime.now();
        final currentDay = now.weekday - 1; 
        final currentTimeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        
        final todayUpcoming = timetable.where((s) => s['day_of_week'] == currentDay && s['start_time'].toString().compareTo(currentTimeStr) > 0).toList();
        if (todayUpcoming.isNotEmpty) {
          todayUpcoming.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
          next = todayUpcoming.first;
        } else {
          for (int i = 1; i <= 7; i++) {
            final nextDay = (currentDay + i) % 7;
            final daySlots = timetable.where((s) => s['day_of_week'] == nextDay).toList();
            if (daySlots.isNotEmpty) {
              daySlots.sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
              next = daySlots.first;
              break;
            }
          }
        }
      }
      
      setState(() {
        _currentClass = slot;
        _announcements = anns;
        _activeSession = active;
        _nextClass = next;
        _history = hist;
        if (active != null) {
          final qrPayload = {
            "session_token": active['session_token'],
            "qr_token": active['qr_secret']
          };
          _qrData = jsonEncode(qrPayload);
        }
        _isLoading = false;
      });
      if (active != null) {
        _startRosterUpdates();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startSession() async {
    final targetClass = _currentClass ?? _nextClass;
    if (targetClass == null) return;
    
    setState(() => _isLoading = true);
    try {
      final position = await _gpsService.getCurrentLocation();
      
      final session = await _apiService.startSession(
        classroomId: targetClass['classroom_id'] ?? 1, 
        subjectId: targetClass['subject_id'] ?? 1,
        durationMins: 60,
        lat: position.latitude,
        long: position.longitude,
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_announcements.isNotEmpty) ...[
            _buildAnnouncementBanner(),
            const SizedBox(height: 12),
          ],
          
          Text(
            _currentClass != null ? "Current Slot" : "Next Class",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3C72).withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    _currentClass != null ? FontAwesomeIcons.chalkboardUser : FontAwesomeIcons.calendarCheck, 
                    size: 40, 
                    color: const Color(0xFF1E3C72),
                  ),
                ),
                const SizedBox(height: 24),
                if (_currentClass != null) ...[
                  Text("Scheduled Now", style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    _currentClass!['subject_name'] ?? "Class", 
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentClass!['subject_code'] ?? "", 
                    style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _startSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72), 
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: Text("Start Attendance Session", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ] else if (_nextClass != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1E3C72).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text("Upcoming", style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nextClass!['subject_name'] ?? "Class", 
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _nextClass!['subject_code'] ?? "", 
                    style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _upcomingMetaItem("Time", _nextClass!['start_time'].toString().substring(0, 5)),
                      _upcomingMetaItem("Room", _nextClass!['room_name'] ?? "N/A"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72), 
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: Text("Start Attendance Early", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ] else ...[
                  Text(
                    "No classes scheduled right now", 
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check your timetable for upcoming sessions", 
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          Text(
            "Recent Session History",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 32, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      "No past sessions found",
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._history.map((h) => _buildHistoryCard(h)),
        ],
      ),
    );
  }

  Widget _upcomingMetaItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _buildHistoryCard(dynamic h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHistoryDetail(h),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E3C72).withOpacity(0.08),
                  child: const FaIcon(FontAwesomeIcons.circleCheck, color: Color(0xFF1E3C72), size: 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h['subject_name'] ?? "Class", 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text("${h['date']}  •  ${h['start_time']}", style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${h['present_count']} Present",
                      style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      "${h['absent_count']} Absent",
                      style: GoogleFonts.inter(color: Colors.red[300], fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHistoryDetail(dynamic h) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h['subject_name'] ?? "Class",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1A1A1A)),
                      ),
                      Text(
                        h['subject_code'] ?? "",
                        style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStatItem("Duration", "${h['duration_mins']}m", const Color(0xFF1E3C72)),
                _detailStatItem("Present", "${h['present_count']}", Colors.green),
                _detailStatItem("Absent", "${h['absent_count']}", Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            _detailRow(FontAwesomeIcons.clock, "Session Started", "${h['date']} at ${h['start_time']}"),
            const SizedBox(height: 12),
            _detailRow(FontAwesomeIcons.locationDot, "Classroom Location", h['room_name'] ?? "Unknown"),
            const SizedBox(height: 12),
            _detailRow(FontAwesomeIcons.circleInfo, "Session Status", h['state'].toString().toUpperCase()),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailStatItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String val) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Center(child: FaIcon(icon, size: 14, color: Colors.grey[600])),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
            Text(val, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1A1A1A))),
          ],
        ),
      ],
    );
  }

  Widget _buildAnnouncementBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Announcements",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            if (_announcements.length > 1)
              Text(
                "Swipe to view",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: PageView.builder(
            itemCount: _announcements.length,
            controller: PageController(viewportFraction: 0.98),
            itemBuilder: (context, index) {
              final ann = _announcements[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3C72).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "NEW",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3C72),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "From HOD",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          ann['created_at'].toString().substring(0, 10),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ann['title'] ?? "Announcement",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: const Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ann['body'] ?? "",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                              maxLines: ann['image_url'] != null ? 3 : 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ann['image_url'] != null) ...[
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}${ann['image_url']}',
                                fit: BoxFit.cover,
                                width: 75,
                                height: 75,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 75,
                                  height: 75,
                                  color: Colors.grey[100],
                                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
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
