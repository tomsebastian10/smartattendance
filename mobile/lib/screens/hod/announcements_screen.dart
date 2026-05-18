import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _deleteAnnouncement(int id) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _apiService.deleteAnnouncement(id);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Announcement deleted successfully.")),
      );
      _loadAnnouncements();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Error deleting: ${e.toString()}")),
      );
    }
  }

  void _showComposeDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String targetRole = 'ALL'; // ALL, STUDENT, FACULTY
    File? selectedImage;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
              DropdownButtonFormField<String>(
                value: targetRole,
                decoration: InputDecoration(
                  labelText: "Target Audience",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text("Everyone (Global)")),
                  DropdownMenuItem(value: 'STUDENT', child: Text("Students Only")),
                  DropdownMenuItem(value: 'FACULTY', child: Text("Teachers Only")),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => targetRole = val);
                },
              ),
              const SizedBox(height: 16),
              
              // Image picker preview / button
              if (selectedImage != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        selectedImage!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedImage = null),
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          radius: 14,
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
                    if (photo != null) {
                      setModalState(() {
                        selectedImage = File(photo.path);
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text("Attach Photo"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isUploadingImage
                      ? null
                      : () async {
                          if (titleController.text.isEmpty || bodyController.text.isEmpty) return;
                          
                          setModalState(() => isUploadingImage = true);
                          
                          try {
                            String? imageUrl;
                            if (selectedImage != null) {
                              imageUrl = await _apiService.uploadAnnouncementImage(selectedImage!.path);
                            }
                            
                            await _apiService.postAnnouncement({
                              "title": titleController.text,
                              "body": bodyController.text,
                              "is_global": targetRole == 'ALL',
                              "target_role": targetRole == 'ALL' ? null : targetRole,
                              "image_url": imageUrl,
                            });
                            
                            if (context.mounted) Navigator.pop(context);
                            _loadAnnouncements();
                          } catch (e) {
                            setModalState(() => isUploadingImage = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to post: ${e.toString()}")),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: isUploadingImage
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Broadcast Now", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
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
    String audienceText = "Everyone";
    if (ann['target_role'] == 'STUDENT') {
      audienceText = "Students Only";
    } else if (ann['target_role'] == 'FACULTY') {
      audienceText = "Teachers Only";
    }

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
                child: Text(audienceText.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1E3C72))),
              ),
              Row(
                children: [
                  Text(ann['created_at'].toString().substring(0, 10), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Delete Announcement?"),
                          content: const Text("Are you sure you want to permanently delete this announcement?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteAnnouncement(ann['id']);
                              },
                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(ann['title'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(ann['body'], style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14, height: 1.4)),
          
          if (ann['image_url'] != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}${ann['image_url']}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey[100],
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
