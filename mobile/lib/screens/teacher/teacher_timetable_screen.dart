import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/api_service.dart';

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    try {
      final slots = await _apiService.getFacultyTimetable();
      setState(() {
        _slots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Teaching Schedule", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTimetable,
              child: _slots.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: 7, // 7 days of the week
                      itemBuilder: (ctx, dayIdx) {
                        final daySlots = _slots.where((s) => s['day_of_week'] == dayIdx).toList();
                        if (daySlots.isEmpty) return const SizedBox.shrink();
                        return _buildDaySection(dayIdx, daySlots);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.calendarXmark, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No classes scheduled", style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDaySection(int dayIdx, List<dynamic> daySlots) {
    const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
          child: Text(days[dayIdx], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E3C72))),
        ),
        ...daySlots.map((slot) => _buildSlotCard(slot)).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSlotCard(dynamic slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E3C72).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(slot['start_time'].toString().substring(0, 5), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1E3C72))),
                Text("to", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                Text(slot['end_time'].toString().substring(0, 5), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF1E3C72))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot['subject_name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.locationDot, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(slot['room_name'], style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: Colors.grey),
        ],
      ),
    );
  }
}
