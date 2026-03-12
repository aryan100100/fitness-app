-- [HEALTH APP] — Feature 9: Workout Tracking
-- Migration: Creates workouts and exercise_sets tables with RLS policies.

-- ============================================================
-- 1. WORKOUTS TABLE
-- ============================================================
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


-- ============================================================
-- 2. EXERCISE SETS TABLE
-- ============================================================
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
