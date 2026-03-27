<div align="center">

# NutriTrack

**Adaptive nutrition coaching that learns from your body — not just your plan.**

*Flutter · Supabase · Gemini AI · iOS*

</div>

---

## Overview

Most nutrition apps fail at the same point: they give you a calorie number on day one and never change it. Real bodies don't behave like spreadsheets. Weight plateaus, life gets chaotic, motivation fluctuates — and the app just sits there judging you with a red progress bar.

NutriTrack is built around a different assumption: **your plan should adapt to you, not the other way around**.

The app calculates personalised TDEE and macro targets from biometric and lifestyle data, then recalibrates those targets weekly using your actual logged weight — not the theoretical projection. If you're losing faster than expected, it eases up. If you've stalled, it adjusts. No manual recalculation required.

Designed for the Indian market first (with full international support), with a food database that actually includes dal, sabzi, and street food — not just "Chicken Breast (grilled)".

---

## Core Features

**Nutrition Tracking**
- Food log with multi-source search: USDA FoodData Central, Nutritionix, OpenFoodFacts, 500+ curated Indian foods (offline-first), custom foods
- On-device barcode scanner via ML Kit — no data leaves the device
- AI meal photo estimator — photograph your plate, get estimated macros via Gemini Vision
- Full macro breakdown: calories, protein, carbs, fat, fiber

**Adaptive Target Engine**
- TDEE calculated from Mifflin-St Jeor BMR + activity level, refined by body fat range and lifting experience
- Weekly recalibration: compares actual 7-day weight average against plan projection, adjusts calorie target if diverging >10%
- Phased adjustments: large corrections are spread over multiple weeks (max ±100 kcal/day per recalibration) — avoids unsustainable swings

**AI-Powered Meal Planning**
- Gemini-generated 7-day meal plans personalised to macro targets, region, life situation, and protein preference
- Recipe generator with dietary filters
- One-tap: log a full AI-generated meal day directly to your food journal

**Emergency Calorie Redistribution**
- If you eat over your target, two options instead of shame:
  - *Redistribute:* reduce remaining days this week slightly to compensate
  - *Extend date:* push the goal end date rather than touching daily targets
- After 3+ emergency uses in 7 days: gentle intervention message suggesting a check-in

**Progress Photos**
- Off by default. Opt-in only, with a wellbeing disclaimer on first use
- Stored in a private Supabase Storage bucket — inaccessible to anyone but the user
- No AI analysis. No automated feedback. Photos are a private journal, not a transformation contest
- Minimum 14-day gap enforced between comparisons to reduce body-checking risk

**Workout Tracking**
- Session-based workout logging with set/rep/weight tracking
- Progressive overload tracking and personal record detection
- Exercise preset library

**Full Profile & Settings**
- Edit all biometric and goal data; triggers full TDEE recalculation on save
- Low Pressure Mode: softer language, reduced check-in frequency
- Hide streak counter (for users who find streaks stressful)
- Data & Privacy screen: view what's stored, delete all data with a single confirmation

---

## How It Works

### TDEE Calculation
Uses Mifflin-St Jeor BMR as the base, adjusted by an activity multiplier (4 levels). Protein targets are then set using a multiplier derived from lifting experience (none → advanced) and body fat range, with protein preference (comfortable / moderate / high) as a user-controlled dial. The result is a full macro split: protein first, then fat floor, carbs from remainder.

### Weekly Recalibration
Every check-in day (user-configurable), the app fetches the last 7 days of weight logs, computes a rolling average, and compares it against the expected weight based on the current deficit or surplus. If the divergence exceeds 10%, the TDEE estimate is recalculated using the actual rate of change as ground truth — not the activity multiplier, which is notoriously inaccurate for self-reporting.

Large corrections are held in a `pending_target_adjustment` buffer and released incrementally to avoid jarring swings. This mirrors the approach used in research-backed adaptive diet protocols.

### Clinical Safeguards
The app tracks Low Motivation events and Emergency Button uses. If both exceed a threshold within a 7-day window, it shows a message recommending professional support — not as a gate, but as a nudge. The threshold is configurable and the user can dismiss and continue. No data is sent anywhere.

All calorie targets are floor-constrained: 1200 kcal minimum for females, 1500 for males — regardless of pace slider setting.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) — iOS primary, Android supported |
| Backend | Supabase (PostgreSQL, Auth, Storage, RLS) |
| AI | Google Gemini 1.5 Flash — meal plans, photo estimation, emergency messages |
| Authentication | Google Sign In, Apple Sign In, Email/Password |
| Barcode | ML Kit via `mobile_scanner` — fully on-device |
| Charts | fl_chart |
| State | Provider (dashboard) + StatefulWidget |
| Fonts | Inter via Google Fonts |
| Food APIs | USDA FoodData Central, Nutritionix, OpenFoodFacts |

---

## Current Status

**Active development. Core product is functional.**

The nutrition tracking loop (log → analyse → adapt) is complete and working end-to-end. Auth (Google, Apple, email), onboarding, food logging, barcode scanning, AI meal planning, progress photos, workout tracking, and the profile screen are all built and passing static analysis with zero warnings.

What's left before App Store submission:
- Supabase Google + Apple OAuth provider configuration
- Xcode: Sign In with Apple capability
- Push notification infrastructure
- App Store Connect listing and screenshots
- TestFlight beta

---

## Roadmap

**Near-term**
- [ ] Push notifications for check-in reminders and streak alerts
- [ ] Apple Watch companion (step count integration for TDEE)
- [ ] Android optimisation pass

**AI / Intelligence**
- [ ] Micro-adjustment suggestions based on logged food patterns ("You tend to go over on Fridays — want to redistribute?")
- [ ] Smarter food logging via conversational entry ("I had a bowl of dal rice with one chapati")
- [ ] Meal plan memory — Gemini learns preferences from past accepted/rejected meals

**Product**
- [ ] Social: optional anonymised progress sharing ("I hit my protein target 21 days straight")
- [ ] Dietitian handoff: export full nutrition history as a PDF summary for healthcare providers
- [ ] Family / household mode: multiple profiles, one subscription

---

## Why This Stands Out

**Most fitness apps are goal-setting tools dressed as tracking tools.** They record what you do but don't close the feedback loop. NutriTrack is built around the feedback loop: actual bodyweight data drives target recalculation, not the other way around.

The wellbeing design is intentional and evidence-based. Progress photos are opt-in with comparison rate-limiting. There is no "you failed" language. The Emergency button reframes going over your target as a problem to redistribute — not a reason to spiral. These aren't UX polish decisions; they're grounded in body image research and the known risks of rigid calorie tracking in vulnerable populations.

The food database prioritises the Indian market — where most nutrition apps fail. Regional foods, correct serving sizes, and offline-first search mean the app is actually usable without hunting for approximations.

---

## Screenshots

> *Coming soon — TestFlight build in progress.*

---

## Setup

```bash
git clone https://github.com/aryan100100/fitness-app
cd fitness-app
cp .env.example .env   # Add your Supabase URL, anon key, and Gemini API key
flutter pub get
flutter run
```

Requires: Flutter 3.x, a Supabase project with the schema applied, and API keys for Gemini.
See `AUTH_SETUP.md` for Google and Apple Sign In configuration.

---

<div align="center">

Built in public. Feedback welcome.

</div>
