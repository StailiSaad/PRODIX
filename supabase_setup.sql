-- ============================================================
-- TeamUp Supabase Schema — Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Users table (required by FK constraints)
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  password_hash text DEFAULT 'managed_by_supabase_auth',
  created_at timestamptz DEFAULT now()
);

-- 2. Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  pseudo text DEFAULT 'Player',
  level text DEFAULT 'intermediaire',
  language text DEFAULT 'fr',
  availability text DEFAULT 'evening',
  game_type text DEFAULT 'FPS',
  role text DEFAULT 'support',
  region text DEFAULT 'EU',
  rank_mmr int DEFAULT 1000,
  bio text DEFAULT '',
  avatar_url text,
  experience_points int DEFAULT 0,
  win_ratio float DEFAULT 50.0,
  matches_played int DEFAULT 0,
  birth_date text,
  favorite_games text[],
  created_at timestamptz DEFAULT now()
);

-- 3. Teams (with optional squad_id for team chat)
CREATE TABLE IF NOT EXISTS public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  avatar_url text,
  status text DEFAULT 'active',
  squad_id uuid REFERENCES public.squads(id) ON DELETE SET NULL,
  game_id text,
  created_at timestamptz DEFAULT now()
);

-- 3b. Team Members
CREATE TABLE IF NOT EXISTS public.team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text DEFAULT 'member',
  status text DEFAULT 'active',
  joined_at timestamptz DEFAULT now(),
  UNIQUE(team_id, user_id)
);

-- Add squad_id to teams if missing
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS squad_id uuid REFERENCES public.squads(id) ON DELETE SET NULL;

-- Add status to team_members if missing
ALTER TABLE public.team_members ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';

-- 3c. Squad (Servers)
CREATE TABLE IF NOT EXISTS public.squads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  logo_url text,
  owner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- 4. Squad Members
CREATE TABLE IF NOT EXISTS public.squad_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text DEFAULT 'member',
  joined_at timestamptz DEFAULT now(),
  UNIQUE(squad_id, user_id)
);

-- 5. Channels
CREATE TABLE IF NOT EXISTS public.channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'general',
  type text DEFAULT 'text',
  created_at timestamptz DEFAULT now()
);

-- 6. Messages (supports both channel messages AND DMs)
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id uuid REFERENCES public.channels(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  status text DEFAULT 'sent',
  media_url text,
  media_type text,
  media_name text,
  duration int,
  created_at timestamptz DEFAULT now()
);

-- 7. Squad Invitations
CREATE TABLE IF NOT EXISTS public.squad_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- 7b. Invitations table (if not already created by prodix_setup.sql)
CREATE TABLE IF NOT EXISTS public.invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 7c. Team invitations (team_id added for team invites)
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams(id) ON DELETE CASCADE;

-- ============================================================
-- Row Level Security (RLS) — Allow all authenticated users
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_invitations ENABLE ROW LEVEL SECURITY;

-- Simple policies: authenticated users can do everything
-- (You can tighten these later for production)
DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['users','profiles','teams','team_members','squads','squad_members','channels','messages','invitations','squad_invitations'])
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%s_all_auth" ON public.%I;', tbl, tbl);
    EXECUTE format('
      CREATE POLICY "%s_all_auth" ON public.%I
        FOR ALL
        TO authenticated
        USING (true)
        WITH CHECK (true);
    ', tbl, tbl);
  END LOOP;
END $$;

-- Enable Realtime for messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END $$;

-- ============================================================
-- Storage Buckets (Avatars)
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true) 
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
CREATE POLICY "Avatar images are publicly accessible."
ON storage.objects FOR SELECT
USING ( bucket_id = 'avatars' );

DROP POLICY IF EXISTS "Users can upload avatars." ON storage.objects;
CREATE POLICY "Users can upload avatars." 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK ( bucket_id = 'avatars' );

DROP POLICY IF EXISTS "Users can update their avatars." ON storage.objects;
CREATE POLICY "Users can update their avatars."
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'avatars' );
