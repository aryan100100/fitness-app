ALTER TABLE streaks
  ADD COLUMN IF NOT EXISTS grace_days_used_this_window integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_grace_day date,
  ADD COLUMN IF NOT EXISTS longest_streak integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_hidden boolean DEFAULT false;

CREATE TABLE IF NOT EXISTS low_motivation_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  used_at timestamptz DEFAULT now(),
  option_chosen text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS day_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  override_date date NOT NULL,
  override_type text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, override_date)
);

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS low_motivation_count integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_low_motivation_use timestamp with time zone,
  ADD COLUMN IF NOT EXISTS last_clinical_flag_shown date,
  ADD COLUMN IF NOT EXISTS hide_streak_counter boolean DEFAULT false;

ALTER TABLE low_motivation_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own low motivation logs"
  ON low_motivation_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE day_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own day overrides"
  ON day_overrides FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
