-- [HEALTH APP] — Feature 10 Migration: Barcode Scanner
-- Run this AFTER feature9 migration.

-- ─────────────────────────────────────────────────────────────
-- 1. Add barcode and source columns to custom_foods
-- ─────────────────────────────────────────────────────────────
ALTER TABLE custom_foods
  ADD COLUMN IF NOT EXISTS barcode text,
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'user_entered';
  -- source values: 'user_entered' | 'barcode_scan' | 'off' | 'nutritionix'

-- Index for fast barcode lookups on user's personal foods
CREATE INDEX IF NOT EXISTS idx_custom_foods_barcode
  ON custom_foods(user_id, barcode)
  WHERE barcode IS NOT NULL;

-- ─────────────────────────────────────────────────────────────
-- 2. Add food_source tracking to food_logs
-- ─────────────────────────────────────────────────────────────
ALTER TABLE food_logs
  ADD COLUMN IF NOT EXISTS food_source text DEFAULT 'manual_search';
  -- values: 'manual_search' | 'barcode_scan' | 'photo_estimate' | 'recent'
