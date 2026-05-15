import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/api_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final data = await _apiService.getAnnouncements();
      setState(() {
        _announcements = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showComposeDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isGlobal = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("New Announcement", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 4,
              decoration: InputDecoration(labelText: "Message Content", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (ctx, setModalState) => SwitchListTile(
                title: Text("Global (All Students)", style: GoogleFonts.inter(fontSize: 14)),
                value: isGlobal,
                activeColor: const Color(0xFF1E3C72),
                onChanged: (val) => setModalState(() => isGlobal = val),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || bodyController.text.isEmpty) return;
                  await _apiService.postAnnouncement({
                    "title": titleController.text,
                    "body": bodyController.text,
                    "is_global": isGlobal,
                  });
                  Navigator.pop(context);
                  _loadAnnouncements();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("Broadcast Now", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Announcements", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: _announcements.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _announcements.length,
                      itemBuilder: (ctx, idx) {
                        final ann = _announcements[idx];
                        return _buildAnnouncementCard(ann);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        backgroundColor: const Color(0xFF1E3C72),
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.bullhorn, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No announcements sent yet", style: GoogleFonts.inter(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic ann) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1E3C72).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(ann['is_global'] ? "GLOBAL" : "SUBJECT", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1E3C72))),
              ),
              Text(ann['created_at'].toString().substring(0, 10), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(ann['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(ann['body'], style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
