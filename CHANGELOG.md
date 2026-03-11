# CHANGELOG — Session: 2026-03-10

All changes made by **Person B (Windows)** in this session.
Your Mac friend: pull these changes and read this file to understand what's new.

---

## New Files

### `lib/features/profile/profile_screen.dart` [NEW]
Full profile & settings screen replacing the dev-only stub.

**What it does:**
- **User info card** — avatar (initial), name, goal, age, activity level, weight, height
- **Daily targets card** — shows current calories, protein, carbs, fat targets
- **Settings section:**
  - Weight unit toggle (kg/lbs) — persists to Supabase
  - Check-in day picker (Mon→Sun) — persists to Supabase  
  - Low Pressure Mode toggle — softer nudges, persists to Supabase
- **Account section** — Sign out with confirmation dialog
- All settings auto-save to Supabase via `SupabaseService.updateUser()`

**Depends on:** `UserModel`, `SupabaseService`, `AppColors`, `AppTextStyles`

---

## Modified Files

### `lib/features/nav_shell.dart` [MODIFIED]
- **Tab 3:** Changed from "Workout" placeholder → **Weight Log** tab (`WeightLogScreen`)
- **Tab 4:** Changed from `DevProfileScreen` → **ProfileScreen** (with user data)
- **Tab 3 icon:** `fitness_center_rounded` → `monitor_weight_rounded`, label "Workout" → "Weight"
- **Imports:** Replaced `dev_profile_screen.dart` → `profile_screen.dart`, added `weight_log_screen.dart`

### `lib/features/weight_log/weight_log_screen.dart` [MODIFIED]
- **Added** optional `showBackButton` parameter (defaults to `false`)
- When used as a **tab** (in nav_shell) → no back button shown
- When **pushed as a modal** (from dashboard) → back button shown
- Set `automaticallyImplyLeading: false` to prevent unwanted back arrows

### `lib/features/dashboard/dashboard_screen.dart` [MODIFIED]
- Updated `_navigateToWeightLog()` to pass `showBackButton: true` when pushing WeightLogScreen as a modal route

---

## Unchanged Files (for reference)
- `lib/features/profile/dev_profile_screen.dart` — **NOT deleted**, but no longer imported anywhere. Can be removed if desired.

---

## Notes for Mac User
- Added `shared_preferences: ^2.5.1` to `pubspec.yaml`
- Make sure to run `flutter pub get` when you pull these changes.
- Existing schema covers all new settings fields (`weight_unit`, `checkin_day`, `low_pressure_mode` in Feature 7).

---

## 2. Offline Caching & Error Handling

### `lib/models/dashboard_summary.dart` [MODIFIED]
- Added `fromJson` and `toJson` methods to allow offline serialization.

### `lib/features/dashboard/dashboard_provider.dart` [MODIFIED]
- **Offline Caching added!**
- Before fetching from Supabase, `DashboardProvider` now loads the last known state (`DashboardSummary` and `_mealLogs`) from `SharedPreferences`.
- If the network fails, the user now stays on the cached dashboard instead of seeing an empty/failed screen.

### `lib/features/food_log/manual_entry_screen.dart` & `food_detail_sheet.dart` [MODIFIED]
- Added proper `ScaffoldMessenger.showSnackBar` error boundaries around Supabase insert calls.
- Users are now properly notified if they try to save a food while offline, rather than failing silently.
