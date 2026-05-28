-- Posts feature: Instagram-style posts with likes, comments (with replies), comment likes

CREATE TABLE IF NOT EXISTS public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caption text DEFAULT '',
  media_urls text[] DEFAULT '{}',
  media_types text[] DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.post_comments(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.post_comment_likes (
  comment_id uuid NOT NULL REFERENCES public.post_comments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id)
);

-- RLS
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "posts_all_auth" ON public.posts;
CREATE POLICY "posts_all_auth" ON public.posts
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "post_likes_all_auth" ON public.post_likes;
CREATE POLICY "post_likes_all_auth" ON public.post_likes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "post_comments_all_auth" ON public.post_comments;
CREATE POLICY "post_comments_all_auth" ON public.post_comments
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "post_comment_likes_all_auth" ON public.post_comment_likes;
CREATE POLICY "post_comment_likes_all_auth" ON public.post_comment_likes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Realtime for posts, likes, comments
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel pr
    JOIN pg_class c ON c.oid = pr.prrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE pr.prpubid = (SELECT oid FROM pg_publication WHERE pubname = 'supabase_realtime')
    AND c.relname = 'posts' AND n.nspname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel pr
    JOIN pg_class c ON c.oid = pr.prrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE pr.prpubid = (SELECT oid FROM pg_publication WHERE pubname = 'supabase_realtime')
    AND c.relname = 'post_likes' AND n.nspname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_likes;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel pr
    JOIN pg_class c ON c.oid = pr.prrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE pr.prpubid = (SELECT oid FROM pg_publication WHERE pubname = 'supabase_realtime')
    AND c.relname = 'post_comments' AND n.nspname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_comments;
  END IF;
END $$;

-- Storage bucket for post media
INSERT INTO storage.buckets (id, name, public)
VALUES ('post_media', 'post_media', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Post media are publicly accessible." ON storage.objects;
CREATE POLICY "Post media are publicly accessible."
  ON storage.objects FOR SELECT USING (bucket_id = 'post_media');

DROP POLICY IF EXISTS "Users can upload post media." ON storage.objects;
CREATE POLICY "Users can upload post media."
  ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'post_media');

DROP POLICY IF EXISTS "Users can update their post media." ON storage.objects;
CREATE POLICY "Users can update their post media."
  ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'post_media');

DROP POLICY IF EXISTS "Users can delete their post media." ON storage.objects;
CREATE POLICY "Users can delete their post media."
  ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'post_media');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent_id ON public.post_comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_post_comment_likes_comment_id ON public.post_comment_likes(comment_id);
