import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isAuthenticating = false;
  String? _errorMessage;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();

    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Get biometric type name and authenticate
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final biometricService = BiometricService();

    // Get friendly name
    final typeName = await biometricService.getBiometricTypeName();
    setState(() => _biometricType = typeName);

    // Auto-trigger authentication
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final biometricService = BiometricService();
    final result = await biometricService.authenticate(
      reason: 'Unlock IPDS Docs to continue',
    );

    if (!mounted) return;

    if (result.success) {
      // Success - navigate to dashboard
      Get.offAllNamed('/dashboard');
    } else {
      // Failed or user cancelled
      setState(() {
        _isAuthenticating = false;
        _errorMessage = result.message;
      });
    }
  }

  void _usePassword() {
    // Navigate to login screen
    BiometricService.reset(); // Set logout flag
    Get.offAllNamed('/login');
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        child: SafeArea(
          child: Column(
            children: [
              // Logo at top
              const SizedBox(height: 60),
              Image.asset('assets/icon.png', width: 80, height: 80),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF9D4EDD)],
                ).createShader(bounds),
                child: const Text(
                  'IPDS Docs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const Spacer(),

              // Biometric icon with pulse animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00D9FF).withOpacity(0.3),
                        const Color(0xFF9D4EDD).withOpacity(0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D9FF).withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 60,
                    color: Color(0xFF00D9FF),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Unlock text
              Text(
                'Unlock with $_biometricType',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Authenticate to access your files',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Retry button (if failed)
              if (_errorMessage != null && !_isAuthenticating)
                TextButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.refresh, color: Color(0xFF00D9FF)),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const Spacer(),

              // Use Password button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _usePassword,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Use Password Instead',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
