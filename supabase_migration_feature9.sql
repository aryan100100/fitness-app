-- [HEALTH APP] — Feature 9 Migration: Progress Photos
-- Run this against your Supabase SQL editor AFTER running feature8 migration.

-- ─────────────────────────────────────────────────────────────
-- 1. progress_photos table
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
-- 2. RLS on progress_photos
-- ─────────────────────────────────────────────────────────────
ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own progress photos"
  ON progress_photos FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 3. User columns for Feature 9
-- ─────────────────────────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS progress_photos_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS progress_photo_reminder_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS progress_photo_reminder_interval_days integer DEFAULT 14,
  ADD COLUMN IF NOT EXISTS last_progress_photo_reminder date,
  ADD COLUMN IF NOT EXISTS progress_photos_comparison_streak integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_comparison_date date;

-- ─────────────────────────────────────────────────────────────
-- 4. Storage bucket
-- Create the 'progress-photos' bucket manually in the Supabase
-- dashboard → Storage → New bucket:
--   Name: progress-photos
--   Public: OFF (private)
--
-- Then add this storage RLS policy via dashboard → Storage →
-- Policies for the 'progress-photos' bucket:
--
-- Policy name: "Users manage own photos"
-- Operation: ALL
-- Expression:
--   (auth.uid())::text = (storage.foldername(name))[1]
-- ─────────────────────────────────────────────────────────────
