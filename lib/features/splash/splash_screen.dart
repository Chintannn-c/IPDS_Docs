import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../auth/presentation/auth_provider.dart';

/// Splash screen shown when app launches
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate after splash delay
    Future.delayed(const Duration(milliseconds: 2500), _handleNavigation);
  }

  Future<void> _handleNavigation() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    try {
      // 1. Ensure device ID/fingerprint is loaded (crucial for block checks)
      if (auth.deviceFingerprint == null) {
        await auth.loadCurrentDeviceId();
      }
      if (!mounted) return;

      // 2. Try to restore session if token exists and not on Web
      // Note: On Web, the AuthProvider constructor clears the token intentionally
      // for a "Fresh Login Only" security policy.
      if (!kIsWeb && !auth.isLoggedIn) {
        final token = await const FlutterSecureStorage().read(
          key: 'access_token',
        );
        if (token != null && token.isNotEmpty) {
          debugPrint('[Splash] Token found on Mobile, restoring session...');
          await auth.restoreSession().timeout(
            const Duration(seconds: 5),
            onTimeout: () =>
                debugPrint('[Splash] Session restoration timed out'),
          );
        }
      }
    } catch (e) {
      debugPrint('[Splash] Error during init: $e');
    }

    if (!mounted) return;

    // 3. Final navigation check
    // If logged in (restored or already active), go to dashboard
    if (auth.isLoggedIn) {
      debugPrint('[Splash] Navigating to Dashboard');
      Get.offAllNamed('/dashboard');
    } else {
      debugPrint('[Splash] Navigating to Login');
      Get.offAllNamed('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // Dark blue
              Color(0xFF1B263B), // Slightly lighter
              Color(0xFF0D1B2A), // Dark blue
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon with glow
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D9FF).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: const Color(0xFF9D4EDD).withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 150,
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // App Name
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF00D9FF),
                        Color(0xFF9D4EDD),
                        Color(0xFF00D9FF),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'IPDS Docs',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  Text(
                    'Intrusion Prevention & Detection System',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Loading indicator
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF00D9FF).withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
