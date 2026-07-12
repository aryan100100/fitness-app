// ┌──────────────────────────────────────────────────────────────────────────┐
// │  TEMPORARY — FOR INTERNAL TESTING ONLY                                 │
// │                                                                        │
// │  These fixed credentials are used to silently create / sign into a     │
// │  single test account on app launch so the login screen is bypassed.    │
// │                                                                        │
// │  ⚠️  REMOVE THIS FILE and all references before any real release.      │
// │                                                                        │
// │  Prerequisites:                                                        │
// │    • Supabase Dashboard → Authentication → Providers → Email           │
// │      → "Confirm email" must be OFF                                     │
// └──────────────────────────────────────────────────────────────────────────┘

class DevAuthConfig {
  DevAuthConfig._();

  /// Set to `true` to bypass the login screen entirely.
  /// Set to `false` to restore normal auth behaviour (WelcomeScreen).
  static const bool enabled = true;

  static const String testEmail = 'test@nutritrack.dev';
  static const String testPassword = 'NutriTrack!Test2026';
}
