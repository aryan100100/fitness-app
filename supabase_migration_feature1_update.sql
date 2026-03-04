-- [HEALTH APP] — Feature 1 Update: Schema Patch
-- Run this in Supabase SQL Editor AFTER supabase_migration_feature2.sql.
-- Adds protein_preference, lifting_experience, and protein_multiplier columns.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS protein_preference  text DEFAULT 'moderate',
  ADD COLUMN IF NOT EXISTS lifting_experience   text,
  ADD COLUMN IF NOT EXISTS protein_multiplier   numeric;
