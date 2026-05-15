import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/api_service.dart';

class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _apiService.getHodLeaveRequests(status: "PENDING");
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Fallback or error UI could go here
    }
  }

  Future<void> _approveRequest(int id) async {
    try {
      await _apiService.approveLeave(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave approved and attendance backfilled!")));
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  Future<void> _rejectRequest(int id) async {
    try {
      await _apiService.rejectLeave(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave request rejected.")));
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Leave Requests", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _requests.length,
                      itemBuilder: (ctx, idx) {
                        final req = _requests[idx];
                        return _buildLeaveCard(req);
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
          FaIcon(FontAwesomeIcons.fileCircleCheck, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("All caught up! No pending requests.", style: GoogleFonts.inter(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(dynamic req) {
    final bool isMedical = req['leave_type'] == 'MEDICAL';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(req['student_name'] ?? "Unknown Student", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isMedical ? Colors.orange : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(req['leave_type'] ?? "LEAVE", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isMedical ? Colors.orange : Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.calendarDay, size: 12, color: Colors.grey),
              const SizedBox(width: 8),
              Text("${req['start_date']} to ${req['end_date']}", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Text(req['reason'] ?? "No reason provided", style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectRequest(req['id']),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text("Reject", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveRequest(req['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text("Approve", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
