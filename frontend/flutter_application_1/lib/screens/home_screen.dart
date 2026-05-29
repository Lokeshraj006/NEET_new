import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/models/home_model.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HomeModel>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _DashboardBackdrop(),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(
                    name: 'NEET Prep',
                    onProfileTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ValueListenableBuilder<String?>(
                      valueListenable: AuthService.nameNotifier,
                      builder: (context, userName, _) {
                        final displayName = (userName != null && userName.trim().isNotEmpty)
                            ? userName.trim()
                            : 'there';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  height: 1.15,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  const TextSpan(text: 'Hello '),
                                  TextSpan(
                                    text: displayName,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Every page you study today is one step closer to the white coat you dream of.\nStay consistent — future doctors are built one day at a time.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                height: 1.7,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DailyStreakHeroCard(
                    streakDays: model.streakDays,
                    bestStreak: model.bestStreak,
                    isLoading: model.isLoadingDaily,
                    statusText: model.dailyStatusText,
                    quote: model.quote,
                    completed: model.dailyCompleted,
                    onTap: () {
                      Navigator.of(context).pushNamed('/streak/daily');
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'NEET syllabus',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SyllabusCard(
                    onTap: () => _openSyllabus(context),
                    onDownloadTap: () => _openSyllabus(context, download: true),
                  ),
                  const SizedBox(height: 14),
                  _AiAssistantBanner(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChatScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: model.selectedIndex,
        onTap: model.setIndex,
      ),
    );
  }

  Future<void> _openSyllabus(BuildContext context, {bool download = false}) async {
    final baseUrl = kIsWeb
        ? 'http://localhost:8000/syllabus/neet.pdf'
        : 'http://10.0.2.2:8000/syllabus/neet.pdf';
    final uri = Uri.parse('$baseUrl${download ? '?download=1' : ''}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open NEET syllabus PDF.')),
      );
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  final VoidCallback onProfileTap;

  const _DashboardHeader({required this.name, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEET Prep',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Medical learning dashboard',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        ValueListenableBuilder<String?>(
          valueListenable: AuthService.photoNotifier,
          builder: (context, photoB64, _) {
            return Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfileTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipOval(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: photoB64 != null
                          ? Image.memory(
                              base64Decode(photoB64),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AiAssistantBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _AiAssistantBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtitleColor = isDark ? Colors.white70 : AppColors.textSecondary;
    // A banner-style, non-card look to separate it from the grid of cards
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF0B1220), Color(0xFF111827)]
                    : const [Color(0xFFDCFCE7), Color(0xFFCFFAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: isDark ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical AI Assistant',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quick explanations • Concept help • Fast revision',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onTap,
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDownloadTap;

  const _SyllabusCard({required this.onTap, required this.onDownloadTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final bodyColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF0F172A), Color(0xFF111827)]
                  : const [Color(0xFFE0F2FE), Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark ? AppColors.border : const Color(0xFFD1FAE5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore the whole syllabus of NEET here',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to view the syllabus PDF. Use download to save it on your device.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: bodyColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: onTap,
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    TextButton(
                      onPressed: onDownloadTap,
                      child: Text(
                        'Download',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyStreakHeroCard extends StatelessWidget {
  final int streakDays;
  final int bestStreak;
  final bool isLoading;
  final String statusText;
  final String quote;
  final bool completed;
  final VoidCallback onTap;

  const _DailyStreakHeroCard({
    required this.streakDays,
    required this.bestStreak,
    required this.isLoading,
    required this.statusText,
    required this.quote,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const [Color(0xFF0B1220), Color(0xFF111827), Color(0xFF1F2937)]
        : const [Color(0xFF082F49), Color(0xFF0F766E), Color(0xFF16A34A)];
    final badgeBg = isDark
        ? AppColors.surface.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.16);
    final ctaBg = isDark ? AppColors.surface : Colors.white;
    final ctaTextColor = isDark ? Colors.white : const Color(0xFF0F766E);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 14)),
            ],
          ),
          child: Stack(
            children: [
              const SizedBox.shrink(),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            completed ? Icons.verified_rounded : Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                completed ? 'Streak locked today' : 'Daily Streak Arena',
                                style: GoogleFonts.poppins(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Solve 3 daily questions and maintain your streak.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TinyStatChip(
                            label: 'Current',
                            value: isLoading ? '--' : streakDays.toString(),
                            suffix: 'days',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TinyStatChip(
                            label: 'Best',
                            value: isLoading ? '--' : bestStreak.toString(),
                            suffix: 'days',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      quote,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          completed ? Icons.lock_rounded : Icons.sports_esports_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: ctaBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            completed ? 'View Result' : 'Enter',
                            style: GoogleFonts.poppins(
                              color: ctaTextColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyStatChip extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final bool isDark;

  const _TinyStatChip({
    required this.label,
    required this.value,
    required this.suffix,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.border : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                suffix,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: const SizedBox.shrink(),
          ),
          Positioned(
            left: -30,
            bottom: 160,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
