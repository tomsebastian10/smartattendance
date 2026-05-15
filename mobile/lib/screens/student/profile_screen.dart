import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final info = await _apiService.getProfile();
      setState(() {
        _userInfo = info;
        _nameController.text = info['name'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{};
      if (_nameController.text.isNotEmpty && _nameController.text != _userInfo?['name']) {
        updates['name'] = _nameController.text;
      }
      if (_newPasswordController.text.isNotEmpty) {
        updates['password'] = _newPasswordController.text;
      }
      if (updates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No changes to save.")),
        );
        return;
      }
      await _apiService.updateProfile(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        _newPasswordController.clear();
        _currentPasswordController.clear();
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text("My Profile", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 32),
                  _buildInfoSection(),
                  const SizedBox(height: 24),
                  _buildPasswordSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final name = _userInfo?['name'] ?? 'S';
    final initials = name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();
    final email = _userInfo?['email'] ?? '';
    final dept = _userInfo?['department'] ?? 'Computer Science';

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3C72).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(initials, style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
        Text(email, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3C72).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(dept, style: GoogleFonts.inter(color: const Color(0xFF1E3C72), fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return _buildCard(
      title: "Personal Information",
      icon: FontAwesomeIcons.circleUser,
      children: [
        _buildField("Full Name", _nameController, FontAwesomeIcons.user),
        const SizedBox(height: 16),
        _buildReadOnlyField("Email", _userInfo?['email'] ?? '', FontAwesomeIcons.envelope),
        const SizedBox(height: 16),
        _buildReadOnlyField("Role", _userInfo?['role'] ?? 'STUDENT', FontAwesomeIcons.graduationCap),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return _buildCard(
      title: "Change Password",
      icon: FontAwesomeIcons.lock,
      children: [
        _buildField("New Password", _newPasswordController, FontAwesomeIcons.key, isPassword: true, hint: "Leave blank to keep current"),
      ],
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 16, color: const Color(0xFF1E3C72)),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E3C72))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool isPassword = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: isPassword,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            prefixIcon: FaIcon(icon, size: 14, color: Colors.grey),
            fillColor: const Color(0xFFF8F9FE),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              FaIcon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 12),
              Text(value, style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveChanges,
        icon: _isSaving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const FaIcon(FontAwesomeIcons.floppyDisk, size: 16),
        label: Text(_isSaving ? "Saving..." : "Save Changes", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3C72),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Logout", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Text("Are you sure you want to log out?", style: GoogleFonts.inter()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              TextButton(
                onPressed: () { Navigator.pop(ctx); _logout(); },
                child: Text("Logout", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 16, color: Colors.red),
        label: Text("Logout", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
