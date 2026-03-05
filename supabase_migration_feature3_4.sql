-- [HEALTH APP] — Feature 3 & 4 Schema Migration
-- Run this in the Supabase SQL Editor after the previous migrations.

-- ---------------------------------------------------------------------------
-- 1. Users table additions (TDEE calibration fields)
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS tdee_recalibrated     numeric,
  ADD COLUMN IF NOT EXISTS tdee_calibration_date date,
  ADD COLUMN IF NOT EXISTS tdee_confidence       text DEFAULT 'building';

-- ---------------------------------------------------------------------------
-- 2. Streaks table (new — tracks daily logging consistency)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.streaks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid REFERENCES public.users(id) ON DELETE CASCADE,
  current_streak int  DEFAULT 0,
  last_log_date  date,
  updated_at     timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own streak"
  ON public.streaks
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3. Custom foods table (new — manual entries + community additions)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.custom_foods (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES public.users(id) ON DELETE CASCADE,
  food_name         text NOT NULL,
  calories_per_100g numeric,
  protein_per_100g  numeric,
  carbs_per_100g    numeric,
  fat_per_100g      numeric,
  fibre_per_100g    numeric,
  source            text DEFAULT 'manual',
  created_at        timestamptz DEFAULT now()
);

ALTER TABLE public.custom_foods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own custom foods"
  ON public.custom_foods
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4. food_logs table additions
-- ---------------------------------------------------------------------------
ALTER TABLE public.food_logs
  ADD COLUMN IF NOT EXISTS fibre_g     numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS food_source text    DEFAULT 'manual';

-- ---------------------------------------------------------------------------
-- Done. Verify by running:
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'users';
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'food_logs';
-- ---------------------------------------------------------------------------
