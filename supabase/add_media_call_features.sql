-- Avatar column on teams
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS avatar_url text;

-- Storage bucket for team avatars
INSERT INTO storage.buckets (id, name, public) VALUES ('team_avatars', 'team_avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS team_avatars_select ON storage.objects;
CREATE POLICY team_avatars_select ON storage.objects
  FOR SELECT USING (bucket_id = 'team_avatars');

DROP POLICY IF EXISTS team_avatars_insert ON storage.objects;
CREATE POLICY team_avatars_insert ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'team_avatars' AND auth.role() = 'authenticated');

-- Storage bucket for chat media
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_media', 'chat_media', true)
ON CONFLICT (id) DO NOTHING;

-- Media columns on messages
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_type text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_name text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS duration int;

-- Calls table for WebRTC signaling
CREATE TABLE IF NOT EXISTS public.calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'ringing',
  call_type text NOT NULL DEFAULT 'audio',
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS for calls
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calls_select ON public.calls;
CREATE POLICY calls_select ON public.calls
  FOR SELECT USING (auth.uid() IN (caller_id, callee_id));

DROP POLICY IF EXISTS calls_insert ON public.calls;
CREATE POLICY calls_insert ON public.calls
  FOR INSERT WITH CHECK (auth.uid() = caller_id);

DROP POLICY IF EXISTS calls_update ON public.calls;
CREATE POLICY calls_update ON public.calls
  FOR UPDATE USING (auth.uid() IN (caller_id, callee_id));

-- RLS for chat_media bucket
DROP POLICY IF EXISTS chat_media_select ON storage.objects;
CREATE POLICY chat_media_select ON storage.objects
  FOR SELECT USING (bucket_id = 'chat_media');

DROP POLICY IF EXISTS chat_media_insert ON storage.objects;
CREATE POLICY chat_media_insert ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'chat_media' AND auth.role() = 'authenticated');

-- Realtime for calls (idempotent — check if member first)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'calls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
