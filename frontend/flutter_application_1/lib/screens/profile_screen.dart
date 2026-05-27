import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/core/widgets/info_tile.dart';
import 'package:flutter_application_1/models/home_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final homeModel = context.watch<HomeModel>();
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
                    'NEET ASPIRANT',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Future doctor in progress',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${homeModel.streakDays} days',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
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
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 4,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
