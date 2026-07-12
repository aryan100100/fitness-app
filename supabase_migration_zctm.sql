-- ============================================================
-- [ZCTM] Zero-Calorie-Tracking Mode Migration
-- Run AFTER all previous feature migrations.
-- Adds waist_logs table, tracking_mode column, and last_waist_prompt column.
-- ============================================================

-- -------------------------------------------------------
-- TABLE: waist_logs
-- One entry per user per day. Upserts replace on conflict.
-- Waist circumference is a body composition proxy used in ZCTM
-- as a progress signal independent of scale weight.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.waist_logs (
  id          uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid         NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  waist_cm    numeric(5,1) NOT NULL,
  logged_at   date         NOT NULL DEFAULT CURRENT_DATE,
  note        text,
  created_at  timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (user_id, logged_at)
);

CREATE INDEX IF NOT EXISTS idx_waist_logs_user_date
  ON public.waist_logs (user_id, logged_at DESC);

-- -------------------------------------------------------
-- RLS: waist_logs
-- -------------------------------------------------------
ALTER TABLE public.waist_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "waist_logs: select own rows"
  ON public.waist_logs FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "waist_logs: insert own rows"
  ON public.waist_logs FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "waist_logs: update own rows"
  ON public.waist_logs FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "waist_logs: delete own rows"
  ON public.waist_logs FOR DELETE
  USING (user_id = auth.uid());

-- -------------------------------------------------------
-- COLUMN: users.tracking_mode
-- 'full'  = standard calorie-tracking mode (existing behaviour)
-- 'zero'  = Zero-Calorie-Tracking Mode (protein-only UI)
-- Defaults to 'full' so all existing users are unaffected.
-- -------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS tracking_mode text NOT NULL DEFAULT 'full'
  CHECK (tracking_mode IN ('full', 'zero'));

-- -------------------------------------------------------
-- COLUMN: users.last_waist_prompt
-- Date when the app last prompted the user to log their waist.
-- Used to throttle the prompt (no more than once per fortnight).
-- -------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_waist_prompt date;

-- ============================================================
-- Migration complete.
-- ============================================================
