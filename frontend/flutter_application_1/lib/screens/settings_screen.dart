import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/widgets/custom_button.dart';
import 'package:flutter_application_1/core/widgets/custom_text_field.dart';
import 'package:flutter_application_1/core/widgets/info_tile.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _nameController.text = (await AuthService.getName()) ?? '';
    _emailController.text = (await AuthService.getEmail()) ?? '';
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = await AuthService.updateProfile(
        name: _nameController.text.trim(),
        currentPassword: _currentPasswordController.text.trim().isEmpty ? null : _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim().isEmpty ? null : _newPasswordController.text.trim(),
      );
      _nameController.text = data['name'] ?? _nameController.text;
      _emailController.text = data['email'] ?? _emailController.text;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            InfoTile(
              icon: Icons.badge_outlined,
              title: 'Display name',
              subtitle: 'Update the name shown across the app.',
              trailing: const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _nameController,
              hintText: 'Your name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            InfoTile(
              icon: Icons.mail_outline_rounded,
              title: 'Email address',
              subtitle: 'Used for sign-in and account identity.',
              trailing: const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _emailController,
              hintText: 'Email address',
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
            const SizedBox(height: 18),
            Text(
              'Password & security',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _currentPasswordController,
              hintText: 'Current password',
              obscureText: true,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _newPasswordController,
              hintText: 'New password',
              obscureText: true,
              prefixIcon: const Icon(Icons.password_rounded),
            ),
            const SizedBox(height: 18),
            const SizedBox(height: 20),
            CustomButton(
              label: 'SAVE CHANGES',
              onPressed: _saving ? null : _save,
              loading: _saving,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 3,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
