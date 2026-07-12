-- ============================================================
-- [HEALTH APP] — Fiber Spelling Consistency Fix
-- Run this in Supabase SQL Editor.
--
-- BUG: supabase_migration.sql creates food_logs WITHOUT fibre_g.
-- The column is added in supabase_migration_feature3_4.sql.
-- If feature3_4 was never run, fibre_g does not exist and all
-- Supabase queries for it silently return null → dashboard shows 0.
--
-- CANONICAL SPELLINGS (do not change):
--   food_logs.fibre_g  → British spelling (established in feature3_4)
--   users.fiber_g      → American spelling (established in initial migration)
--   All Dart files already match their respective tables correctly.
--
-- This migration is idempotent (safe to run multiple times).
-- ============================================================

-- -------------------------------------------------------
-- 1. Ensure fibre_g exists on food_logs
--    (no-op if feature3_4 migration was already run)
-- -------------------------------------------------------
ALTER TABLE public.food_logs
  ADD COLUMN IF NOT EXISTS fibre_g numeric DEFAULT 0;

-- -------------------------------------------------------
-- 2. Ensure food_source exists on food_logs
--    (also added in feature3_4, same guard)
-- -------------------------------------------------------
ALTER TABLE public.food_logs
  ADD COLUMN IF NOT EXISTS food_source text DEFAULT 'manual';

-- -------------------------------------------------------
-- 3. Ensure fiber_g exists on users
--    (created in initial migration — guard for safety)
-- -------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS fiber_g numeric NOT NULL DEFAULT 0;

-- -------------------------------------------------------
-- 4. Verify both columns now exist
-- Run this SELECT to confirm after migration:
-- -------------------------------------------------------
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'food_logs' AND column_name = 'fibre_g'
-- UNION ALL
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'users' AND column_name = 'fiber_g';
--
-- Expected output: 2 rows, one for each table.
-- ============================================================
