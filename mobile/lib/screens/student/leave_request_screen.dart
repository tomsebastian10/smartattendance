import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  String _leaveType = "MEDICAL";
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();
  XFile? _proofImage;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera),
              title: Text("Take Photo", style: GoogleFonts.inter()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.images),
              title: Text("Choose from Gallery", style: GoogleFonts.inter()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => _proofImage = picked);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      String? documentUrl;
      if (_proofImage != null) {
        final bytes = await _proofImage!.readAsBytes();
        documentUrl = await _apiService.uploadProofBytes(bytes, _proofImage!.name);
      }

      await _apiService.applyLeave({
        "leave_type": _leaveType,
        "start_date": _startDate.toIso8601String().split('T')[0],
        "end_date": _endDate.toIso8601String().split('T')[0],
        "reason": _reasonController.text,
        "document_url": documentUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave request submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _proofImage = null;
          _reasonController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("Leave & OD Requests", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildDateSection(),
              const SizedBox(height: 24),
              Text("Reason", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                style: GoogleFonts.inter(),
                decoration: InputDecoration(
                  hintText: "Explain why you need leave...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value!.isEmpty ? "Please enter a reason" : null,
              ),
              const SizedBox(height: 24),
              Text("Proof Document", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _buildProofUploader(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Submit Request", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Leave Type", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            _typeChip("MEDICAL", FontAwesomeIcons.briefcaseMedical, "Medical"),
            const SizedBox(width: 12),
            _typeChip("ON_DUTY", FontAwesomeIcons.userCheck, "On Duty"),
          ],
        ),
      ],
    );
  }

  Widget _typeChip(String type, IconData icon, String label) {
    bool isSelected = _leaveType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _leaveType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3C72) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF1E3C72) : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              FaIcon(icon, color: isSelected ? Colors.white : Colors.grey, size: 22),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Duration", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _datePickerCard("From", _startDate, (d) {
              setState(() {
                _startDate = d;
                if (_endDate.isBefore(_startDate)) {
                  _endDate = _startDate;
                }
              });
            })),
            const SizedBox(width: 16),
            Expanded(child: _datePickerCard("To", _endDate, (d) => setState(() => _endDate = d), minDate: _startDate)),
          ],
        ),
      ],
    );
  }

  Widget _datePickerCard(String label, DateTime date, Function(DateTime) onPick, {DateTime? minDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            DateTime initial = date;
            DateTime first = minDate ?? DateTime.now().subtract(const Duration(days: 60));
            if (initial.isBefore(first)) initial = first;
            
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: first,
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.calendar, size: 14, color: Color(0xFF1E3C72)),
                const SizedBox(width: 8),
                Text("${date.day}/${date.month}/${date.year}", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: _proofImage != null ? 180 : 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: _proofImage != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: kIsWeb 
                      ? Image.network(_proofImage!.path, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(File(_proofImage!.path), width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _proofImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.cloudArrowUp, color: Color(0xFF1E3C72), size: 28),
                const SizedBox(height: 8),
                Text("Tap to upload proof", style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                Text("Medical certificate, OD letter, etc.", style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
      ),
    );
  }
}
