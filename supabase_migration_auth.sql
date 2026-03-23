-- [HEALTH APP] — Auth Migration (Feature 12)
-- No schema changes needed — Supabase Auth handles user accounts automatically.
-- Run this in the Supabase SQL editor to ensure correct RLS policies.

-- Ensure authenticated users can insert their own profile (new sign-ups)
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Ensure authenticated users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Ensure authenticated users can read their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON users;
CREATE POLICY "Users can read own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- (Optional) Allow authenticated users to delete their own profile
DROP POLICY IF EXISTS "Users can delete own profile" ON users;
CREATE POLICY "Users can delete own profile"
  ON users FOR DELETE
  USING (auth.uid() = id);
