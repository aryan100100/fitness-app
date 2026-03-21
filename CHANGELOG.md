# CHANGELOG — Session: 2026-03-12 (Part 2)

All changes made by **Person B (Windows)** in this session.
Your Mac friend: pull these changes and read this file to understand what's new.

---

## Premium UI Overhaul (Phase 2) — NEW DESIGN SYSTEM

> **⚠️ Important:** The app has been fully redesigned to match a premium, modern iOS-grade aesthetic. If you've been working on UI components, you may need to resolve some merge conflicts.

### Global Design System Updates
- Enforced a stark, two-color theme: **True OLED Black** background (`#000000`) and a vibrant **Orange** primary accent (`#FF9500`).
- Shifted all cards and surfaces to greyscale tones (`#1C1C1E`, `#2C2C2E`) with a glassy, translucent `BottomNavBar`.
- Standardized corner radii strictly to `24.0` for large cards and `16.0`/`12.0` for inner pills.
- Switched default typography to use geometric, bolder sans-serif weights (e.g., `FontWeight.w700` for headers) using `AppTextStyles`.

### Emoji Purge & Iconography
- **Removed ALL String-based emojis** across every single screen (Dashboard, Diet Planner, Food Log, and Onboarding).
- Replaced them with elegant, minimalist line-art `IconData` (e.g., `Icons.*_outlined` and `Icons.*_rounded`) to eliminate visual clutter and present a mature, premium feel.

### Specific Screen Refinements
- **Bottom Navigation Shell:** Now uses `extendBody: true` to render content cleanly beneath a blurred glassmorphism navigation bar.
- **Workout Screen:** Fixed a padding bug where the `BottomNavBar` was occluding the "Log Workout" floating action button. Added a `90.0` bottom padding lift to the FAB and `160.0` clearance to the list scroll.
- **Dashboard & Calorie Ring:** Re-styled the ring progress with a thicker stroke width (`18.0`) and sleek circular caps. Extracted emojis from the stat pills and replaced them with `Icons.restaurant_outlined` and `Icons.flag_outlined`.
- **Onboarding Variables:** All 8 onboarding screens were updated heavily to align with the new design tokens and icons.

---

# CHANGELOG — Session: 2026-03-12 (Part 1)

All changes made by **Person B (Windows)** in this session.
Your Mac friend: pull these changes and read this file to understand what's new.

---

## 3. Workout Tracking (Feature 9) — NEW FEATURE

> **⚠️ Important:** Run the new SQL migration `supabase_migration_feature9.sql` in your Supabase SQL editor before testing workouts.

### New Files

#### `lib/models/workout_model.dart` [NEW]
Data model for a workout session (name, type, duration, notes).

#### `lib/models/exercise_set_model.dart` [NEW]
Data model for individual exercise sets within a workout. Supports both strength (sets/reps/weight) and cardio (duration/distance).

#### `lib/core/services/workout_service.dart` [NEW]
Supabase CRUD service for workouts and exercise sets. Includes weekly stats helpers (`getWeeklyWorkoutCount`, `getWeeklyDurationMinutes`).

#### `lib/features/workout/workout_screen.dart` [NEW]
Main workout tab (Tab 3) screen:
- Weekly summary cards (workout count, total time, streak indicator)
- Recent workout list with expandable exercise details
- Pull-to-refresh, delete confirmation dialog
- FAB to log new workout

#### `lib/features/workout/log_workout_screen.dart` [NEW]
Workout entry form:
- Workout metadata: name, type (strength/cardio/flexibility/sports via ChoiceChips), duration, notes
- Dynamic exercise builder: add/remove exercises with muscle group picker
- Set-level input: reps/weight for strength, duration/distance for cardio
- Full error handling with SnackBars

#### `supabase_migration_feature9.sql` [NEW]
Creates `workouts` and `exercise_sets` tables with RLS policies and indexes.

### Modified Files

#### `lib/features/nav_shell.dart` [MODIFIED]
- **Tab 3** changed from `WeightLogScreen` → `WorkoutScreen`
- Icon changed from `monitor_weight_rounded` → `fitness_center_rounded`, label "Weight" → "Workout"
- `WeightLogScreen` is still accessible from the Dashboard modal navigation

---

## Notes for Mac User
- Run `flutter pub get` after pulling
- **Run `supabase_migration_feature9.sql`** in Supabase SQL Editor to create the workout tables
- Test the Workout tab (4th tab in bottom nav)

---

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
