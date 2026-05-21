import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/custom_button.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/core/widgets/info_tile.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _name;
  String? _email;
  String? _photoB64;
  bool _uploading = false;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _authListener = () {
      if (!mounted) return;
      setState(() {
        _name = AuthService.nameNotifier.value;
        _email = AuthService.emailNotifier.value;
        _photoB64 = AuthService.photoNotifier.value;
      });
    };
    AuthService.nameNotifier.addListener(_authListener);
    AuthService.emailNotifier.addListener(_authListener);
    AuthService.photoNotifier.addListener(_authListener);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await AuthService.getName();
    final email = await AuthService.getEmail();
    final photo = await AuthService.getPhoto();
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
      _photoB64 = photo;
    });
    AuthService.nameNotifier.value = name;
    AuthService.emailNotifier.value = email;
    AuthService.photoNotifier.value = photo;
  }

  @override
  void dispose() {
    AuthService.nameNotifier.removeListener(_authListener);
    AuthService.emailNotifier.removeListener(_authListener);
    AuthService.photoNotifier.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final b64 = await AuthService.uploadPhoto(File(picked.path));
      if (!mounted) return;
      setState(() => _photoB64 = b64);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarRadius = 56.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InfoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUpload,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: AppColors.primarySoft,
                          backgroundImage: _photoB64 != null
                              ? MemoryImage(base64Decode(_photoB64!))
                              : null,
                          child: _photoB64 == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 46,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        if (_uploading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name ?? 'NEET Student',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email ?? '-',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoCard(
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      title: 'Streak',
                      value: '14 days',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatChip(
                      title: 'Completion',
                      value: '78%',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoTile(
              icon: Icons.tune_rounded,
              title: 'Account settings',
              subtitle: 'Edit personal information and security preferences.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign out from this device and clear the local session.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomButton(
                    label: 'LOGOUT',
                    outlined: true,
                    onPressed: _logout,
                  ),
                ],
              ),
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

class _StatChip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
