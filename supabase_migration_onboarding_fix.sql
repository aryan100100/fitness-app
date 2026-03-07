-- [HEALTH APP] — Onboarding Fix SQL Patch
-- Run this in Supabase SQL Editor.
-- Safe to run multiple times (idempotent).
-- No schema changes — all columns already exist.
-- This ONLY fixes RLS policies and enables anonymous auth integration.

-- ---------------------------------------------------------------------------
-- 1. Ensure the users INSERT policy is correct.
--    Drop and recreate to guarantee it matches the expected condition.
--    The critical rule: id must equal auth.uid() exactly.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "users: insert own row" ON public.users;

CREATE POLICY "users: insert own row"
  ON public.users FOR INSERT
  WITH CHECK (id = auth.uid());

-- Also re-ensure SELECT, UPDATE, DELETE policies exist cleanly:
DROP POLICY IF EXISTS "users: select own row" ON public.users;
CREATE POLICY "users: select own row"
  ON public.users FOR SELECT
  USING (id = auth.uid());

DROP POLICY IF EXISTS "users: update own row" ON public.users;
CREATE POLICY "users: update own row"
  ON public.users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Verify columns exist (defensive adds — safe if already present).
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS body_fat_range         text,
  ADD COLUMN IF NOT EXISTS weekly_pace_percent     numeric,
  ADD COLUMN IF NOT EXISTS daily_deficit_surplus   numeric,
  ADD COLUMN IF NOT EXISTS protein_preference      text DEFAULT 'moderate',
  ADD COLUMN IF NOT EXISTS lifting_experience      text,
  ADD COLUMN IF NOT EXISTS protein_multiplier      numeric,
  ADD COLUMN IF NOT EXISTS tdee_recalibrated       numeric,
  ADD COLUMN IF NOT EXISTS tdee_calibration_date   date,
  ADD COLUMN IF NOT EXISTS tdee_confidence         text DEFAULT 'building';

-- ---------------------------------------------------------------------------
-- 3. Done. Verify by running:
--    SELECT id, name, protein_preference FROM public.users LIMIT 5;
-- ---------------------------------------------------------------------------
