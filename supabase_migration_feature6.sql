-- [HEALTH APP] — Feature 6: Emergency Button Schema Migration
-- Run in Supabase SQL Editor AFTER all previous migrations.

-- ---------------------------------------------------------------------------
-- 1. emergency_button_logs — tracks every use for intervention detection
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.emergency_button_logs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES public.users(id) ON DELETE CASCADE,
  used_at      timestamptz DEFAULT now(),
  overage_kcal numeric,
  option_chosen text,       -- 'redistribute' | 'extend_date'
  week_number  integer,     -- ISO week number for grouping
  created_at   timestamptz DEFAULT now()
);

ALTER TABLE public.emergency_button_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "emergency_logs: own rows"
  ON public.emergency_button_logs FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. daily_targets — add override columns (table may already exist)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_targets (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid        REFERENCES public.users(id) ON DELETE CASCADE,
  date                 date        NOT NULL,
  target_calories      numeric     NOT NULL,
  is_emergency_override boolean    DEFAULT false,
  override_expires_at  date,
  created_at           timestamptz DEFAULT now(),
  UNIQUE (user_id, date)
);

ALTER TABLE public.daily_targets ADD COLUMN IF NOT EXISTS is_emergency_override boolean DEFAULT false;
ALTER TABLE public.daily_targets ADD COLUMN IF NOT EXISTS override_expires_at date;

ALTER TABLE public.daily_targets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_targets: own rows"
  ON public.daily_targets FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. users — add emergency usage tracking columns
-- ---------------------------------------------------------------------------
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS emergency_button_count integer DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_emergency_use timestamptz;

-- ---------------------------------------------------------------------------
-- Verify:
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public'
-- AND table_name IN ('emergency_button_logs', 'daily_targets');
-- ---------------------------------------------------------------------------
