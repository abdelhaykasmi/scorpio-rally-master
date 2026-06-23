import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/models.dart';
import 'services/auth_provider.dart';
import 'services/app_settings_provider.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/participant/participant_home.dart';
import 'screens/organizer/organizer_home.dart';
import 'screens/admin/admin_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize Supabase ──────────────────────────────────
  await Supabase.initialize(
    url: 'https://xlkdkzghcwxakujgzvkz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhsa2RremdoY3d4YWt1amd6dmt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNzI5NTAsImV4cCI6MjA5Nzc0ODk1MH0'
        '.2qnQNB3Z6c3rfCbDGHBiuHgJCUG8CRZYe6Cs1P1msxU',
  );

  // ── Seed demo data (no-op if already seeded) ─────────────
  await SupabaseService.instance.seedDemoDataIfNeeded();

  // ── Load persisted app settings ──────────────────────────
  final settings = AppSettingsProvider();
  await settings.load();

  runApp(RaidApp(settings: settings));
}

class RaidApp extends StatelessWidget {
  final AppSettingsProvider settings;
  const RaidApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          title: 'Off-Road Experience ${s.appTitle}',
          debugShowCheckedModeBanner: false,
          theme: s.buildTheme(),
          home: const _AppRouter(),
        ),
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
        if (auth.isLoading) return const _SplashScreen();
        if (!auth.isLoggedIn) return const LoginScreen();
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
    final s = context.watch<AppSettingsProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or default icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: s.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: s.hasLogo
                  ? ClipOval(
                      child: Image.memory(s.logoBytes!, fit: BoxFit.cover))
                  : const Icon(Icons.two_wheeler,
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
            Text(
              s.appTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: s.appTitle.length > 6 ? 32 : 48,
                fontWeight: FontWeight.w900,
                letterSpacing: s.appTitle.length > 6 ? 4 : 10,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                color: s.primaryColor,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
