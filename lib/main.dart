// [HEALTH APP] — App Entry Point
// Initialises flutter_dotenv then Supabase before runApp.
// On startup: checks for existing auth session.
// If session + users row found → goes to dashboard directly (skip onboarding).
// Otherwise → OnboardingScreen.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_colors.dart';
import 'core/services/supabase_service.dart';
import 'features/nav_shell.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load .env
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[MAIN] .env loaded OK');
    debugPrint('[MAIN] SUPABASE_URL = ${dotenv.env['SUPABASE_URL']}');
  } catch (e) {
    debugPrint('[MAIN] WARNING: .env failed to load: $e');
    // Continue — Supabase will initialise with empty strings and fail gracefully
  }

  // 2. Initialise Supabase with a timeout guard
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[MAIN] Supabase.initialize timed out after 10s');
        // Returns without throwing — app continues with a potentially
        // non-functional client, which is handled by the router's fallback.
        return Supabase.instance;
      },
    );
    debugPrint('[MAIN] Supabase initialised OK');
  } catch (e) {
    debugPrint('[MAIN] Supabase.initialize error: $e');
    // Continue — router will send user to onboarding
  }

  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '[HEALTH APP]',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryAccent,
          surface: AppColors.cardSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryAccent, width: 2),
          ),
          hintStyle: const TextStyle(color: AppColors.secondaryText),
          labelStyle: const TextStyle(color: AppColors.secondaryText),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const _AppRouter(),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth-aware router.
// FIX: Navigation is deferred to addPostFrameCallback so the Navigator widget
// is fully mounted before pushReplacement is called. Calling Navigator from
// initState directly causes '!navigator._debugLocked' assertion crash.
// ---------------------------------------------------------------------------
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  @override
  void initState() {
    super.initState();
    // CRITICAL: defer navigation until AFTER the first frame is built.
    // Navigator is not available during initState / first build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    debugPrint('[ROUTER] Checking auth session...');
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    // No session → onboarding immediately, no network call needed
    if (session == null || session.user.id.isEmpty) {
      debugPrint('[ROUTER] No session → OnboardingScreen');
      _goToOnboarding();
      return;
    }

    debugPrint('[ROUTER] Session found: ${session.user.id}');

    // Session exists → check if users row exists, with a 5s timeout fallback
    try {
      final existingUser = await SupabaseService.instance
          .fetchCurrentUser()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[ROUTER] fetchCurrentUser timed out → Onboarding');
              return null;
            },
          );

      if (!mounted) return;

      if (existingUser != null) {
        debugPrint('[ROUTER] User row found → Dashboard');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BottomNavShell(user: existingUser),
          ),
        );
      } else {
        debugPrint('[ROUTER] No user row found → OnboardingScreen');
        _goToOnboarding();
      }
    } catch (e) {
      debugPrint('[ROUTER] fetchCurrentUser error: $e → OnboardingScreen');
      _goToOnboarding();
    }
  }

  void _goToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  color: AppColors.primaryAccent, size: 30),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
