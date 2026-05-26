-- Add xp column to profiles, remove old rank and mmr columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;

-- Migrate existing rank_mmr to xp (approximate: 1xp = 2mmr equivalent)
UPDATE public.profiles SET xp = GREATEST(0, COALESCE(rank_mmr, 0) / 2) WHERE xp = 0;

-- Drop old columns (optional — uncomment when confident)
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS level;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS rank_mmr;
