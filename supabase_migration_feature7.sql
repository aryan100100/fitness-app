-- [HEALTH APP] — Feature 7: Auto Adjustments Schema Migration
-- Run in Supabase SQL Editor AFTER all previous migrations.

-- ---------------------------------------------------------------------------
-- 1. weight_logs — daily weight entries for the 7-day rolling average system
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.weight_logs (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid        REFERENCES public.users(id) ON DELETE CASCADE,
  weight_kg          numeric     NOT NULL,
  logged_at          date        NOT NULL DEFAULT CURRENT_DATE,
  is_menstrual_phase boolean     DEFAULT false,
  note               text,
  created_at         timestamptz DEFAULT now(),
  UNIQUE (user_id, logged_at)  -- one entry per day; upsert replaces if user re-logs same day
);

ALTER TABLE public.weight_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "weight_logs: own rows"
  ON public.weight_logs FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Index for fast recent-weight queries
CREATE INDEX IF NOT EXISTS idx_weight_logs_user_date
  ON public.weight_logs (user_id, logged_at DESC);

-- ---------------------------------------------------------------------------
-- 2. users — new columns for auto-adjustment tracking
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS goal_date_reminder_shown boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_situation3_prompt    date,
  ADD COLUMN IF NOT EXISTS last_divergence_check     date,
  ADD COLUMN IF NOT EXISTS last_weekly_recalc_date   date,
  ADD COLUMN IF NOT EXISTS previous_weekly_weight    numeric,
  ADD COLUMN IF NOT EXISTS pending_target_adjustment numeric  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS checkin_day               integer  DEFAULT 1,   -- 1=Mon … 7=Sun (ISO)
  ADD COLUMN IF NOT EXISTS low_pressure_mode         boolean  DEFAULT false,
  ADD COLUMN IF NOT EXISTS weight_unit               text     DEFAULT 'kg';
