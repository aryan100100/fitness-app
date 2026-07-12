// [HEALTH APP] — App Entry Point
// Initialises flutter_dotenv then Supabase before runApp.
// On startup: checks for existing auth session.
// No session + DevAuthConfig.enabled → auto-sign-in with test account (no UI).
// No session + DevAuthConfig.disabled → WelcomeScreen (real auth).
// Session + completed onboarding → Dashboard.
// Session + incomplete onboarding → OnboardingScreen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/dev_auth_config.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/supabase_service.dart';
import 'features/auth/welcome_screen.dart';
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
    debugPrint('[MAIN] WARNING: .env could not be loaded: $e');
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

class _AppRouterState extends State<_AppRouter> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // CRITICAL: defer navigation until AFTER the first frame is built.
    // Navigator is not available during initState / first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route();
      _startAuthListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  // ── Global auth state listener ────────────────────────────────────────────
  // Fires on every auth event. On signedOut / userDeleted → re-auth or WelcomeScreen.
  void _startAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('[AUTH LISTENER] Event: $event');
        if (event == AuthChangeEvent.signedOut) {
          _handleSessionLost();
        }
        // tokenRefreshed, passwordRecovery, etc. → no action needed
      },
      onError: (error) {
        debugPrint('[AUTH LISTENER] Stream error: $error');
      },
    );
  }

  // ── App lifecycle — check session on resume ───────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionOnResume();
    }
  }

  void _checkSessionOnResume() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('[RESUME] No session — re-authenticating');
      _handleSessionLost();
    } else if (session.isExpired) {
      debugPrint('[RESUME] Session expired — signing out and re-authenticating');
      Supabase.instance.client.auth.signOut();
      _handleSessionLost();
    }
    // Valid session → do nothing
  }

  // ── Session lost handler ─────────────────────────────────────────────────
  // TEMP: When DevAuthConfig.enabled, silently re-auth instead of showing
  // WelcomeScreen. When disabled, falls back to normal WelcomeScreen redirect.
  void _handleSessionLost() {
    if (!mounted) return;
    if (DevAuthConfig.enabled) {
      debugPrint('[AUTH] Session lost — silently re-authenticating test account');
      _autoAuthAndRoute();
    } else {
      _redirectToWelcome();
    }
  }

  // ── Redirect helper (normal auth flow) ───────────────────────────────────
  void _redirectToWelcome() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session expired — please sign in again.'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1A1A1A),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _route() async {
    debugPrint('[ROUTER] Checking auth session...');
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    // No session → auto-auth (if DevAuthConfig enabled) or WelcomeScreen
    if (session == null || session.user.id.isEmpty) {
      if (DevAuthConfig.enabled) {
        debugPrint('[ROUTER] No session → auto-auth (DevAuthConfig enabled)');
        await _autoAuthAndRoute();
      } else {
        debugPrint('[ROUTER] No session → WelcomeScreen');
        _goToWelcome();
      }
      return;
    }

    debugPrint('[ROUTER] Session found: ${session.user.id}');
    await _routeAuthenticatedUser();
  }

  // ── TEMP: Silent auto-auth with fixed test account ────────────────────────
  // Tries signIn first; if the account doesn't exist yet, falls back to signUp.
  // After auth succeeds, proceeds to normal authenticated routing.
  Future<void> _autoAuthAndRoute() async {
    try {
      debugPrint('[DEV AUTH] Attempting sign-in as ${DevAuthConfig.testEmail}');
      var result = await AuthService.instance.signInWithEmail(
        DevAuthConfig.testEmail,
        DevAuthConfig.testPassword,
      );

      // If sign-in failed (account may not exist yet), try sign-up
      if (!result.success) {
        debugPrint('[DEV AUTH] Sign-in failed (${result.error}) — trying sign-up');
        result = await AuthService.instance.signUpWithEmail(
          DevAuthConfig.testEmail,
          DevAuthConfig.testPassword,
        );
      }

      if (!result.success) {
        debugPrint('[DEV AUTH] Both sign-in and sign-up failed: ${result.error}');
        // Fallback to WelcomeScreen so the user can debug
        if (mounted) _goToWelcome();
        return;
      }

      debugPrint('[DEV AUTH] Authenticated successfully');
      if (mounted) await _routeAuthenticatedUser();
    } catch (e) {
      debugPrint('[DEV AUTH] Unexpected error: $e');
      if (mounted) _goToWelcome();
    }
  }

  // ── Common post-auth routing ──────────────────────────────────────────────
  Future<void> _routeAuthenticatedUser() async {
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
        debugPrint('[ROUTER] No user row → OnboardingScreen');
        _goToOnboarding();
      }
    } catch (e) {
      debugPrint('[ROUTER] fetchCurrentUser error: $e → Onboarding');
      _goToOnboarding();
    }
  }

  void _goToWelcome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
    );
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
