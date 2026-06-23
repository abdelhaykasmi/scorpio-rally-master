import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'services/auth_provider.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/participant/participant_home.dart';
import 'screens/organizer/organizer_home.dart';
import 'screens/admin/admin_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seed demo data
  await FirebaseService.instance.seedDemoDataIfNeeded();
  runApp(const RaidApp());
}

class RaidApp extends StatelessWidget {
  const RaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: MaterialApp(
        title: 'Off-Road Experience RAID',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AppRouter(),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const _SplashScreen();
        }
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        switch (auth.currentUser?.role) {
          case UserRole.superAdmin:
            return const AdminHome();
          case UserRole.organizer:
            return const OrganizerHome();
          case UserRole.participant:
          default:
            return const ParticipantHome();
        }
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.two_wheeler,
                  size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('OFF-ROAD EXPERIENCE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                )),
            const SizedBox(height: 6),
            const Text('RAID',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                )),
            const SizedBox(height: 40),
            const SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
