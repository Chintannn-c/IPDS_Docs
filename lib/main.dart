import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

// Providers
import 'package:file_stroage_system/core/providers/device_provider.dart';
import 'package:file_stroage_system/core/providers/time_provider.dart';
import 'package:file_stroage_system/core/providers/theme_provider.dart';
import 'package:file_stroage_system/features/auth/presentation/auth_provider.dart';
import 'package:file_stroage_system/features/dashboard/presentation/file_provider.dart';
import 'package:file_stroage_system/features/ipds/presentation/ipds_provider.dart';
import 'package:file_stroage_system/features/items/presentation/items_provider.dart';
import 'package:file_stroage_system/features/dashboard/presentation/summary_provider.dart';

// API
import 'package:file_stroage_system/core/api/api_client.dart';

// Services & Theme
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/core/services/local_notification_service.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/controllers/notification_controller.dart';

// Screen
import 'package:file_stroage_system/features/items/presentation/items_screen.dart';
import 'package:file_stroage_system/features/splash/splash_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/login_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/register_screen.dart';
import 'package:file_stroage_system/features/dashboard/presentation/main_screen.dart';
import 'package:file_stroage_system/features/profile/presentation/profile_screen.dart';
import 'package:file_stroage_system/features/ipds/presentation/ipds_screen.dart';
import 'package:file_stroage_system/features/dashboard/presentation/all_files_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/mfa_setup_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/change_password_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/forgot_password_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/biometric_lock_screen.dart';
import 'package:file_stroage_system/features/items/presentation/add_item_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/device_trust_screen.dart';
import 'package:file_stroage_system/features/ipds/presentation/screens/admin_ipds_dashboard.dart';
import 'package:file_stroage_system/core/presentation/screens/notification_center_screen.dart';
import 'package:file_stroage_system/features/items/presentation/history_screen.dart';
import 'package:file_stroage_system/features/dashboard/presentation/document_analysis_screen.dart';

void main() async {
  print('\n\n🚀🚀🚀 MAIN FUNCTION STARTED 🚀🚀🚀\n');

  WidgetsFlutterBinding.ensureInitialized();
  print('✅ Flutter bindings initialized');

  // Load .env file first
  await dotenv.load(fileName: ".env");
  print('✅ .env file loaded');

  // Initialize ApiClient (creates Dio instance)
  await ApiClient().init();
  print('✅ ApiClient initialized');

  // Initialize Local Notifications
  print('\n🔔 STARTING NOTIFICATION INITIALIZATION...');
  try {
    await LocalNotificationService().initialize();
    print('✅ LocalNotificationService initialized successfully!');
  } catch (e, stack) {
    print('❌ ERROR initializing LocalNotificationService:');
    print('Error: $e');
    print('Stack: $stack');
  }
  print('🔔 NOTIFICATION INITIALIZATION COMPLETED\n');

  print('🚀 Running app...\n\n');
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => IPDSProvider()),
        ChangeNotifierProvider(create: (_) => ItemsProvider()),
        ChangeNotifierProvider(create: (_) => SummaryProvider()),
        ChangeNotifierProvider(
          create: (context) => DeviceProvider(context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => TimeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          return Consumer2<ThemeProvider, AuthProvider>(
            builder: (context, themeProvider, authProvider, _) {
              // Note: Auth navigation is now handled atomically by AuthProvider.logout()
              // and SplashScreen. This prevents build-phase navigation loops.

              return GetMaterialApp(
                navigatorKey: navigatorKey,
                title: 'IPDS Docs',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                scaffoldMessengerKey: NotificationService.messengerKey,
                debugShowCheckedModeBanner: false,
                initialRoute: '/',
                // Initialize NotificationController on app start
                onInit: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    print(
                      'GetMaterialApp onInit - Initializing NotificationController...',
                    );
                    Get.put(NotificationController(), permanent: true);
                    print('NotificationController initialized!');
                  });
                },
                routes: {
                  '/': (context) => const SplashScreen(),
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                  '/dashboard': (context) => const MainScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/ipds': (context) => const IPDSScreen(),
                  '/all_files': (context) => const AllFilesScreen(),
                  '/mfa_setup': (context) => const MFASetupScreen(),
                  '/change-password': (context) => const ChangePasswordScreen(),
                  '/biometric-lock': (context) => const BiometricLockScreen(),
                  '/items': (context) => const ItemsScreen(),
                  '/items/add': (context) => const AddItemScreen(),
                  '/devices': (context) => const DeviceTrustScreen(),
                  '/admin/ipds': (context) => const AdminIPDSDashboard(),
                  '/forgot-password': (context) => const ForgotPasswordScreen(),
                  '/history': (context) => const HistoryScreen(),
                  '/notifications': (context) => NotificationCenterScreen(),
                  '/document_analysis': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments;
                    if (args == null || args is! Map<String, dynamic>) {
                      // Fallback: navigate back to dashboard if args are invalid
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/dashboard');
                      });
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    // Safe string extraction helper
                    String safeGetString(dynamic value, String fallback) {
                      if (value == null) return fallback;
                      if (value is String) return value;
                      if (value is Map || value is List) return fallback;
                      return value.toString();
                    }

                    final fileId = safeGetString(args['fileId'], '');
                    final filename = safeGetString(args['filename'], 'Unknown');

                    // Validate that we have required data
                    if (fileId.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/dashboard');
                      });
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return DocumentAnalysisScreen(
                      fileId: fileId,
                      filename: filename,
                    );
                  },
                },
              );
            },
          );
        },
      ),
    );
  }
}
