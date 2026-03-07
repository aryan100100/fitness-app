-- [HEALTH APP] — Feature 5: AI Diet Planner Schema Migration
-- Run in Supabase SQL Editor AFTER all previous migrations.
-- Creates user_pantry and saved_recipes tables with RLS.

-- ---------------------------------------------------------------------------
-- 1. user_pantry — user's default available foods list
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_pantry (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        REFERENCES public.users(id) ON DELETE CASCADE,
  food_name  text        NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_pantry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pantry: own rows"
  ON public.user_pantry FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. saved_recipes — user's saved AI-generated recipes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.saved_recipes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES public.users(id) ON DELETE CASCADE,
  recipe_name text,
  recipe_data jsonb,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.saved_recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipes: own rows"
  ON public.saved_recipes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Verify:
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' AND table_name IN ('user_pantry','saved_recipes');
-- ---------------------------------------------------------------------------
