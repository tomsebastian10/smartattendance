import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'announcements_screen.dart';
import 'leave_review_screen.dart';
import '../student/profile_screen.dart';

class HodMainNavigation extends StatefulWidget {
  const HodMainNavigation({super.key});

  @override
  State<HodMainNavigation> createState() => _HodMainNavigationState();
}

class _HodMainNavigationState extends State<HodMainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AnnouncementsScreen(),
    const LeaveReviewScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, FontAwesomeIcons.bullhorn, "Alerts"),
                _navItem(1, FontAwesomeIcons.fileSignature, "Leaves"),
                _navItem(2, FontAwesomeIcons.circleUser, "Profile"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3C72).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 20, color: isSelected ? const Color(0xFF1E3C72) : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1E3C72) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
