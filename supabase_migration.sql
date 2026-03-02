-- ============================================================
-- [HEALTH APP] — SQL Migration Script
-- Paste this entire block into Supabase SQL Editor and click Run.
-- Creates all 4 tables, enables RLS, and adds RLS policies.
-- Free-tier compatible: uses only built-in Supabase features.
-- ============================================================

-- -------------------------------------------------------
-- TABLE: users
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text        NOT NULL,
  age               int         NOT NULL,
  biological_sex    text        NOT NULL CHECK (biological_sex IN ('male', 'female')),
  height_cm         numeric     NOT NULL,
  weight_kg         numeric     NOT NULL,
  target_weight_kg  numeric,
  goal              text        NOT NULL CHECK (goal IN ('lose', 'gain', 'maintain')),
  activity_level    text        NOT NULL,
  life_situation    text        NOT NULL,
  region            text        NOT NULL DEFAULT 'India',
  tdee              numeric     NOT NULL DEFAULT 0,
  target_calories   numeric     NOT NULL DEFAULT 0,
  protein_g         numeric     NOT NULL DEFAULT 0,
  carbs_g           numeric     NOT NULL DEFAULT 0,
  fat_g             numeric     NOT NULL DEFAULT 0,
  fiber_g           numeric     NOT NULL DEFAULT 0,
  goal_start_date   date,
  goal_end_date     date,
  food_preferences  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- -------------------------------------------------------
-- TABLE: food_logs
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_logs (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date              date        NOT NULL,
  meal_type         text        NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  food_name         text        NOT NULL,
  quantity_g        numeric     NOT NULL DEFAULT 0,
  calories          numeric     NOT NULL DEFAULT 0,
  protein_g         numeric     NOT NULL DEFAULT 0,
  carbs_g           numeric     NOT NULL DEFAULT 0,
  fat_g             numeric     NOT NULL DEFAULT 0,
  is_photo_estimate boolean     NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- -------------------------------------------------------
-- TABLE: daily_targets
-- Per-day calorie target overrides (used by Emergency Button)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_targets (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date            date        NOT NULL,
  target_calories numeric     NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

-- -------------------------------------------------------
-- TABLE: meal_plans
-- Stores full AI-generated plan JSON per user per day
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.meal_plans (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date        date        NOT NULL,
  plan_data   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- Each user can only read and write their own rows.
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_targets  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans     ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------
-- RLS POLICIES: users table
-- NOTE: users.id must match auth.uid() for the row to be accessible.
-- -------------------------------------------------------
CREATE POLICY "users: select own row"
  ON public.users FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "users: insert own row"
  ON public.users FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "users: update own row"
  ON public.users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "users: delete own row"
  ON public.users FOR DELETE
  USING (id = auth.uid());

-- -------------------------------------------------------
-- RLS POLICIES: food_logs table
-- -------------------------------------------------------
CREATE POLICY "food_logs: select own rows"
  ON public.food_logs FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "food_logs: insert own rows"
  ON public.food_logs FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "food_logs: update own rows"
  ON public.food_logs FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "food_logs: delete own rows"
  ON public.food_logs FOR DELETE
  USING (user_id = auth.uid());

-- -------------------------------------------------------
-- RLS POLICIES: daily_targets table
-- -------------------------------------------------------
CREATE POLICY "daily_targets: select own rows"
  ON public.daily_targets FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "daily_targets: insert own rows"
  ON public.daily_targets FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "daily_targets: update own rows"
  ON public.daily_targets FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "daily_targets: delete own rows"
  ON public.daily_targets FOR DELETE
  USING (user_id = auth.uid());

-- -------------------------------------------------------
-- RLS POLICIES: meal_plans table
-- -------------------------------------------------------
CREATE POLICY "meal_plans: select own rows"
  ON public.meal_plans FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "meal_plans: insert own rows"
  ON public.meal_plans FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "meal_plans: update own rows"
  ON public.meal_plans FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "meal_plans: delete own rows"
  ON public.meal_plans FOR DELETE
  USING (user_id = auth.uid());

-- ============================================================
-- Migration complete. All 4 tables created with RLS.
-- ============================================================
