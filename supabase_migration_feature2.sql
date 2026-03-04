-- [HEALTH APP] — Feature 2 Schema Patch
-- Run this in Supabase SQL Editor AFTER the original migration script.
-- Adds 3 new columns to the users table for the pace slider system.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS body_fat_range         text,
  ADD COLUMN IF NOT EXISTS weekly_pace_percent     numeric,
  ADD COLUMN IF NOT EXISTS daily_deficit_surplus   numeric;
