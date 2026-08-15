import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MedicalProfilePage extends StatelessWidget {
  final String role; // 'Doctor' or 'Counsellor'
  final VoidCallback? onSignOut;

  const MedicalProfilePage({super.key, required this.role, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FAFC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildProfileCard(context),
                    const SizedBox(height: 16),
                    _buildPersonalInfoCard(),
                    const SizedBox(height: 16),
                    _buildSettingsCard(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.add_box, color: Color(0xFF2C5282), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'NIFT Shillong Health',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C5282),
                ),
              ),
            ],
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE2E8F0),
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
              ],
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            role == 'Doctor' ? 'Dr. Medical Officer' : 'Counsellor',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A202C)),
          ),
          const SizedBox(height: 4),
          Text(
            role == 'Doctor' ? 'Chief Medical Officer' : 'Student Counsellor',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF718096)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPill(Icons.business, 'NIFT Campus', const Color(0xFFEBF8FF), const Color(0xFF3182CE)),
              const SizedBox(width: 8),
              _buildPill(Icons.location_on, 'Shillong', const Color(0xFFEDF2F7), const Color(0xFF4A5568)),
            ],
          ),
          const SizedBox(height: 8),
          _buildPill(Icons.verified, 'Verified Staff', const Color(0xFFB2F5EA), const Color(0xFF048A81)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile coming soon!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003D4C),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildPill(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6FFFA)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF003D4C)),
              const SizedBox(width: 8),
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF003D4C)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Email', 'mo.shillong@nift.ac.in'),
          const Divider(height: 28, color: Color(0xFFE6FFFA)),
          _buildInfoRow('Phone', '+91 98765 43210'),
          const Divider(height: 28, color: Color(0xFFE6FFFA)),
          _buildInfoRow('Office Hours', 'Mon – Fri, 9:00 AM – 5:00 PM'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF718096))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // About row
          _buildMenuRow(
            icon: Icons.info_outline_rounded,
            iconBg: const Color(0xFFEBF8FF),
            iconColor: const Color(0xFF3182CE),
            label: 'About App',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'NIFT Hostel Health',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 NIFT Shillong',
              );
            },
            showDivider: true,
          ),
          // Help row
          _buildMenuRow(
            icon: Icons.help_outline_rounded,
            iconBg: const Color(0xFFF0FFF4),
            iconColor: const Color(0xFF38A169),
            label: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact: it.shillong@nift.ac.in')),
              );
            },
            showDivider: true,
          ),
          // Sign Out row
          _buildMenuRow(
            icon: Icons.logout_rounded,
            iconBg: const Color(0xFFFFF5F5),
            iconColor: const Color(0xFFE53E3E),
            label: 'Sign Out',
            labelColor: const Color(0xFFE53E3E),
            onTap: onSignOut != null
                ? () => _confirmSignOut(context)
                : null,
            showDivider: false,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05);
  }

  Widget _buildMenuRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback? onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? const Color(0xFF2D3748),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: labelColor?.withValues(alpha: 0.6) ?? const Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 72, endIndent: 20, color: Color(0xFFF0F0F0)),
      ],
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE53E3E), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign Out?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A202C)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be returned to the login screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF718096), height: 1.5),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF4A5568), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSignOut?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFE53E3E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
