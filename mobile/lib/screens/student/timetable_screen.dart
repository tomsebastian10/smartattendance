import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _slots = [];
  int _selectedDayIndex = DateTime.now().weekday - 1; // 0-6

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    try {
      final slots = await _apiService.getTimetable();
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
        title: Text("Weekly Schedule", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDayPicker(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildSlotList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker() {
    return Container(
      height: 80,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          bool isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3C72) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _days[index],
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotList() {
    final filteredSlots = _slots.where((slot) => slot['day_of_week'] == _selectedDayIndex).toList();

    if (filteredSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.calendarCheck, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text("No classes today!", style: GoogleFonts.inter(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredSlots.length,
      itemBuilder: (context, index) {
        final slot = filteredSlots[index];
        return _buildTimetableCard(slot);
      },
    );
  }

  Widget _buildTimetableCard(Map<String, dynamic> slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot['start_time'].substring(0, 5),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                slot['end_time'].substring(0, 5),
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['subject_name'],
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.locationDot, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      slot['room_name'],
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
