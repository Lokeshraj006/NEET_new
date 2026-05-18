import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  String? _name;
  String? _photoB64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await AuthService.getName();
    final photo = await AuthService.getPhoto();
    setState(() { _name = name; _photoB64 = photo; });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: SvgPicture.asset('assets/profile.svg'),
          ),
          const SizedBox(width: 10),
          const Text('NEET Prep', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        ],
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.black54)),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            _load(); // reload after returning from profile
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _photoB64 != null ? MemoryImage(base64Decode(_photoB64!)) : null,
                  child: _photoB64 == null ? const Icon(Icons.person, color: Colors.black54, size: 20) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
