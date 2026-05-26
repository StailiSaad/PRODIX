-- ============================================================
-- Fix messages table: support both channel messages AND DMs
-- ============================================================

-- 1. Make channel_id nullable (DMs don't have a channel)
ALTER TABLE public.messages ALTER COLUMN channel_id DROP NOT NULL;

-- 2. Add receiver_id for direct messages
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS receiver_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3. Add columns used by the Flutter app
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS status text DEFAULT 'sent';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_type text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_name text;

-- 4. Ensure Realtime is enabled for messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;
