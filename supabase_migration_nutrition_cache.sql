-- ============================================================
-- [HEALTH APP] — Nutrition Cache Table
-- Supabase SQL migration for server-side nutrition API caching.
-- Paste into Supabase Dashboard → SQL Editor and click Run.
--
-- Purpose: caches USDA and Open Food Facts API responses server-side,
--          reducing API calls and improving cold-start performance.
--
-- Cache TTL guidelines (enforced by app logic, not DB):
--   Generic food searches  → 7 days
--   Barcode lookups        → 30 days
--   USDA food details      → 90 days
--
-- No RLS — nutrition facts are public data, not user-specific.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.food_network_cache (
  cache_key       text        PRIMARY KEY,
  provider        text        NOT NULL CHECK (provider IN ('usda', 'openfoodfacts', 'nutritionix')),
  query           text        NOT NULL,
  response_json   jsonb       NOT NULL DEFAULT '[]'::jsonb,
  fetched_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL
);

COMMENT ON TABLE public.food_network_cache IS
  'Server-side cache for USDA and Open Food Facts API responses. Shared across all users. No RLS needed.';

COMMENT ON COLUMN public.food_network_cache.cache_key IS
  'Deterministic key: "{provider}:{type}:{query_or_barcode}", e.g. "usda:search:chicken breast"';

COMMENT ON COLUMN public.food_network_cache.response_json IS
  'Array of UnifiedFood JSON objects as returned by the provider.';

-- Expired entry cleanup: allows efficient deletion sweep
CREATE INDEX IF NOT EXISTS idx_food_cache_expires
  ON public.food_network_cache (expires_at);

-- Provider-level filtering (e.g. clear all USDA cache)
CREATE INDEX IF NOT EXISTS idx_food_cache_provider
  ON public.food_network_cache (provider);

-- ============================================================
-- Migration complete. Run `supabase_migration_nutrition_cache.sql`
-- ============================================================
