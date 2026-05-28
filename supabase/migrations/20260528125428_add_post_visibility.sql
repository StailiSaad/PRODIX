-- Add visibility column to posts table
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public';

-- Index for visibility filtering
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON public.posts(visibility);
