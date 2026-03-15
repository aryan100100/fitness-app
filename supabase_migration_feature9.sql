-- [HEALTH APP] — Feature 9 Migration: Workout Tracking + Progress Photos
-- Contains migrations from both person-b/fitness and person-a/nutrition branches.
-- Run this against your Supabase SQL editor AFTER running feature8 migration.

-- ============================================================
-- PART A: Workout Tracking (person-b/fitness)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. workouts table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workouts (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date        DATE NOT NULL,
  name        TEXT NOT NULL DEFAULT 'Workout',
  type        TEXT NOT NULL DEFAULT 'strength',   -- 'strength' | 'cardio' | 'flexibility' | 'sports'
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  notes       TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- RLS: users can only access their own workouts
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own workouts"
  ON workouts
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for fast date-range queries
CREATE INDEX idx_workouts_user_date ON workouts(user_id, date DESC);


-- ─────────────────────────────────────────────────────────────
-- 2. exercise_sets table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS exercise_sets (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  workout_id      UUID REFERENCES workouts(id) ON DELETE CASCADE NOT NULL,
  exercise_name   TEXT NOT NULL,
  category        TEXT NOT NULL DEFAULT 'other',  -- 'chest' | 'back' | 'legs' | 'shoulders' | 'arms' | 'core' | 'cardio' | 'other'
  set_number      INTEGER NOT NULL DEFAULT 1,
  reps            INTEGER,
  weight_kg       DOUBLE PRECISION,
  duration_seconds INTEGER,
  distance_km     DOUBLE PRECISION,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- RLS: cascade through workouts ownership
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own exercise sets"
  ON exercise_sets
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM workouts
      WHERE workouts.id = exercise_sets.workout_id
      AND workouts.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workouts
      WHERE workouts.id = exercise_sets.workout_id
      AND workouts.user_id = auth.uid()
    )
  );

-- Index for fast lookup by workout
CREATE INDEX idx_exercise_sets_workout ON exercise_sets(workout_id, set_number);


-- ============================================================
-- PART B: Progress Photos (person-a/nutrition)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 3. progress_photos table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS progress_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  photo_date date NOT NULL,
  angle text NOT NULL CHECK (angle IN ('front', 'side', 'back')),
  storage_path text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, photo_date, angle)
);

-- ─────────────────────────────────────────────────────────────
-- 4. RLS on progress_photos
-- ─────────────────────────────────────────────────────────────
ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own progress photos"
  ON progress_photos FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 5. User columns for Progress Photos (Feature 9)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS progress_photos_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS progress_photo_reminder_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS progress_photo_reminder_interval_days integer DEFAULT 14,
  ADD COLUMN IF NOT EXISTS last_progress_photo_reminder date,
  ADD COLUMN IF NOT EXISTS progress_photos_comparison_streak integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_comparison_date date;

-- ─────────────────────────────────────────────────────────────
-- 6. Storage bucket (manual steps)
-- Create the 'progress-photos' bucket in Supabase dashboard:
--   Name: progress-photos
--   Public: OFF (private)
--
-- Then add storage RLS policy:
--   Policy name: "Users manage own photos"
--   Operation: ALL
--   Expression:
--     (auth.uid())::text = (storage.foldername(name))[1]
-- ─────────────────────────────────────────────────────────────
