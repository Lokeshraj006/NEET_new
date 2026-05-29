import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/models/home_model.dart';
import 'package:flutter_application_1/screens/home_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  final bool loggedIn;

  const SplashScreen({super.key, required this.loggedIn});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _ecgController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _ecgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );
    _pulseAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _textFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
    );

    _mainController.forward();
    _ecgController.repeat();

    Timer(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      if (widget.loggedIn) {
        await context.read<HomeModel>().refreshDailyChallenge();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, a1, a2) =>
              widget.loggedIn ? const HomeScreen() : const LoginScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _ecgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: AnimatedBlob(size: 220, color: AppColors.surface.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -40,
            right: -30,
            child: AnimatedBlob(
              size: 260,
              color: AppColors.surface.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 140,
            right: 16,
            child: AnimatedBlob(
              size: 92,
              color: AppColors.surface.withValues(alpha: 0.14),
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _mainController,
                      curve: const Interval(0.0, 1.0, curve: Curves.linear),
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.06,
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(painter: _DNAHelixPainter()),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 0.9, end: 1.25).animate(
                                _pulseAnim,
                              ),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.18),
                                      AppColors.primarySoft.withValues(alpha: 0.06),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Hero(
                              tag: 'app_logo',
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0B1220), Color(0xFF111827)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.medical_services_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: AnimatedBuilder(
                        animation: _ecgController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ECGPainter(
                              progress: _ecgController.value,
                              color: AppColors.primary,
                            ),
                            size: const Size(double.infinity, 40),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(_textFade),
                        child: Column(
                          children: [
                            Text(
                              'Focus  Practice  Succeed',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: 0.8,
                              child: Text(
                                'Focused NEET practice for future doctors',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

class AnimatedBlob extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedBlob({super.key, required this.size, required this.color});

  @override
  State<AnimatedBlob> createState() => _AnimatedBlobState();
}

class _AnimatedBlobState extends State<AnimatedBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final dx = math.sin(_ctrl.value * math.pi * 2) * 8;
        final dy = math.cos(_ctrl.value * math.pi * 2) * 6;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ECGPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ECGPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final offsetX = w * progress;
    path.moveTo(0, h * 0.6);
    for (double x = 0; x <= w; x += 8) {
      final t = ((x + offsetX) % 120) / 120;
      final y = h * (0.6 - math.sin(t * math.pi * 2) * 0.18 * math.exp(-t * 1.5));
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ECGPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _DNAHelixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final w = size.width;
    final h = size.height;
    final path = Path();
    for (double t = 0; t <= 1; t += 0.02) {
      final x = w * t;
      final y1 = h * 0.5 + math.sin(t * math.pi * 6) * (h * 0.12);
      final y2 = h * 0.5 + math.sin(t * math.pi * 6 + math.pi) * (h * 0.12);
      path.moveTo(x, y1);
      path.lineTo(x, y2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}