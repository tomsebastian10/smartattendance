import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _apiService.getStudentStats();
      final profile = await _apiService.getProfile();
      final anns = await _apiService.getAnnouncements();
      setState(() {
        _stats = stats;
        _stats!['_name'] = profile['name'];
        _announcements = anns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading data: $e")),
        );
      }
    }
  }

  Widget _buildAnnouncementBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.bullhorn, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _announcements.first['title'] ?? "Announcement",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notifications", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _notifTile(FontAwesomeIcons.triangleExclamation, "Attendance Warning", "Your Network Security attendance dropped below 75%", Colors.orange),
            const SizedBox(height: 12),
            _notifTile(FontAwesomeIcons.circleCheck, "Leave Approved", "Your OD request for May 10 has been approved", Colors.green),
            const SizedBox(height: 12),
            _notifTile(FontAwesomeIcons.calendarCheck, "Class Reminder", "Cloud Computing starts in 30 minutes in L-101", const Color(0xFF1E3C72)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _notifTile(IconData icon, String title, String body, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: FaIcon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(body, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double overall = (_stats?['overall_attendance'] ?? 0.0) / 100.0;
    final String prediction = _stats?['prediction'] ?? "Loading your goals...";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              if (_announcements.isNotEmpty) _buildAnnouncementBanner(),
              _buildHeader(),
              const SizedBox(height: 30),
              _buildOverallAttendance(overall),
              const SizedBox(height: 24),
              _buildPredictiveCard(prediction),
              const SizedBox(height: 30),
              _buildTrendSection(),
              const SizedBox(height: 30),
              _buildSubjectGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            Text(
              _stats?['_name'] ?? "Student",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _showNotifications,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const FaIcon(FontAwesomeIcons.bell, size: 20, color: Color(0xFF1E3C72)),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallAttendance(double percent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 50.0,
            lineWidth: 10.0,
            percent: percent,
            center: Text(
              "${(percent * 100).toInt()}%",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: Colors.white.withOpacity(0.2),
            progressColor: Colors.white,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Attendance",
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  percent >= 0.75 ? "Looking Good!" : "Take Care!",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    percent >= 0.75 ? "Safe Zone" : "Warning",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictiveCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.lightbulb, color: Colors.amber, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Attendance Trends",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.only(right: 20, top: 10, bottom: 10),
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
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 70),
                    FlSpot(1, 85),
                    FlSpot(2, 80),
                    FlSpot(3, 90),
                    FlSpot(4, 88),
                    FlSpot(5, 95),
                    FlSpot(6, 92),
                  ],
                  isCurved: true,
                  gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)]),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3C72).withOpacity(0.2),
                        const Color(0xFF2A5298).withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectGrid() {
    final List stats = _stats?['subject_stats'] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your Subjects",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All subjects shown below")),
              ),
              child: Text("View All", style: GoogleFonts.inter(color: const Color(0xFF1E3C72))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            return _buildSubjectCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final double percent = (subject['attendance_percentage'] ?? 0.0) / 100.0;
    final Color color = percent >= 0.75 ? Colors.green : (percent >= 0.65 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(FontAwesomeIcons.bookOpen, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['subject_name'] ?? "",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  subject['subject_code'] ?? "",
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${subject['attendance_percentage']}%",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
