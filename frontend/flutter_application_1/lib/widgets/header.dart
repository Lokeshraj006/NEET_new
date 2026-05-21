import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  String? _name;
  String? _photoB64;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _authListener = () {
      if (!mounted) return;
      setState(() {
        _name = AuthService.nameNotifier.value;
        _photoB64 = AuthService.photoNotifier.value;
      });
    };
    AuthService.nameNotifier.addListener(_authListener);
    AuthService.photoNotifier.addListener(_authListener);
    _load();
  }

  Future<void> _load() async {
    final name = await AuthService.getName();
    final photo = await AuthService.getPhoto();
    if (!mounted) return;
    setState(() {
      _name = name;
      _photoB64 = photo;
    });
    AuthService.nameNotifier.value = name;
    AuthService.photoNotifier.value = photo;
  }

  @override
  void dispose() {
    AuthService.nameNotifier.removeListener(_authListener);
    AuthService.photoNotifier.removeListener(_authListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      titleSpacing: 18,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEET Prep',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
              ),
              Text(
                _name == null ? 'Welcome back' : 'Hi, ${_name!}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: _photoB64 != null ? MemoryImage(base64Decode(_photoB64!)) : null,
              child: _photoB64 == null
                  ? const Icon(Icons.person_rounded, color: AppColors.primary)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
