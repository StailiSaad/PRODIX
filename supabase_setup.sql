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
-- Row Level Security (RLS) — Fine-grained policies
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
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_ice_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_favorite_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reputation_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- ── users: own record only ──────────────────────────────────────
DROP POLICY IF EXISTS "users_own" ON public.users;
CREATE POLICY "users_own" ON public.users
  FOR ALL TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ── profiles: all can read (social app), own profile write ──────
DROP POLICY IF EXISTS "profiles_read_all" ON public.profiles;
CREATE POLICY "profiles_read_all" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "profiles_own_write" ON public.profiles;
CREATE POLICY "profiles_own_write" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_own_update" ON public.profiles;
CREATE POLICY "profiles_own_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_own_delete" ON public.profiles;
CREATE POLICY "profiles_own_delete" ON public.profiles
  FOR DELETE TO authenticated
  USING (id = auth.uid());

-- ── teams: members can view; owner can manage ───────────────────
DROP POLICY IF EXISTS "teams_read_member" ON public.teams;
CREATE POLICY "teams_read_member" ON public.teams
  FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "teams_insert" ON public.teams;
CREATE POLICY "teams_insert" ON public.teams
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "teams_update_owner" ON public.teams;
CREATE POLICY "teams_update_owner" ON public.teams
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "teams_delete_owner" ON public.teams;
CREATE POLICY "teams_delete_owner" ON public.teams
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- ── team_members: members can view; owner/admin can manage ──────
DROP POLICY IF EXISTS "team_members_read" ON public.team_members;
CREATE POLICY "team_members_read" ON public.team_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "team_members_insert" ON public.team_members;
CREATE POLICY "team_members_insert" ON public.team_members
  FOR INSERT TO authenticated
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role IN ('leader', 'owner')
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "team_members_update" ON public.team_members;
CREATE POLICY "team_members_update" ON public.team_members
  FOR UPDATE TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role IN ('leader', 'owner')
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "team_members_delete" ON public.team_members;
CREATE POLICY "team_members_delete" ON public.team_members
  FOR DELETE TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role IN ('leader', 'owner')
    )
    OR user_id = auth.uid()
  );

-- ── squads: members can view; owner can manage ──────────────────
DROP POLICY IF EXISTS "squads_read_member" ON public.squads;
CREATE POLICY "squads_read_member" ON public.squads
  FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT squad_id FROM public.squad_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "squads_insert" ON public.squads;
CREATE POLICY "squads_insert" ON public.squads
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "squads_update_owner" ON public.squads;
CREATE POLICY "squads_update_owner" ON public.squads
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "squads_delete_owner" ON public.squads;
CREATE POLICY "squads_delete_owner" ON public.squads
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- ── squad_members: members can view; owner can manage ───────────
DROP POLICY IF EXISTS "squad_members_read" ON public.squad_members;
CREATE POLICY "squad_members_read" ON public.squad_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM public.squad_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "squad_members_insert" ON public.squad_members;
CREATE POLICY "squad_members_insert" ON public.squad_members
  FOR INSERT TO authenticated
  WITH CHECK (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "squad_members_update" ON public.squad_members;
CREATE POLICY "squad_members_update" ON public.squad_members
  FOR UPDATE TO authenticated
  USING (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "squad_members_delete" ON public.squad_members;
CREATE POLICY "squad_members_delete" ON public.squad_members
  FOR DELETE TO authenticated
  USING (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
    OR user_id = auth.uid()
  );

-- ── channels: squad members can view; squad owner can manage ────
DROP POLICY IF EXISTS "channels_read" ON public.channels;
CREATE POLICY "channels_read" ON public.channels
  FOR SELECT TO authenticated
  USING (
    squad_id IN (
      SELECT squad_id FROM public.squad_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "channels_insert" ON public.channels;
CREATE POLICY "channels_insert" ON public.channels
  FOR INSERT TO authenticated
  WITH CHECK (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

DROP POLICY IF EXISTS "channels_update" ON public.channels;
CREATE POLICY "channels_update" ON public.channels
  FOR UPDATE TO authenticated
  USING (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

DROP POLICY IF EXISTS "channels_delete" ON public.channels;
CREATE POLICY "channels_delete" ON public.channels
  FOR DELETE TO authenticated
  USING (
    squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

-- ── messages: participants can view; sender can manage ──────────
DROP POLICY IF EXISTS "messages_read" ON public.messages;
CREATE POLICY "messages_read" ON public.messages
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
    OR channel_id IN (
      SELECT c.id FROM public.channels c
      WHERE c.squad_id IN (
        SELECT squad_id FROM public.squad_members WHERE user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "messages_insert" ON public.messages;
CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "messages_update" ON public.messages;
CREATE POLICY "messages_update" ON public.messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid());

DROP POLICY IF EXISTS "messages_delete" ON public.messages;
CREATE POLICY "messages_delete" ON public.messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- ── invitations: sender or receiver can view/manage ─────────────
DROP POLICY IF EXISTS "invitations_read" ON public.invitations;
CREATE POLICY "invitations_read" ON public.invitations
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
  );

DROP POLICY IF EXISTS "invitations_insert" ON public.invitations;
CREATE POLICY "invitations_insert" ON public.invitations
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "invitations_update" ON public.invitations;
CREATE POLICY "invitations_update" ON public.invitations
  FOR UPDATE TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
  );

DROP POLICY IF EXISTS "invitations_delete" ON public.invitations;
CREATE POLICY "invitations_delete" ON public.invitations
  FOR DELETE TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
  );

-- ── squad_invitations: sender, receiver, or squad owner ─────────
DROP POLICY IF EXISTS "squad_invitations_read" ON public.squad_invitations;
CREATE POLICY "squad_invitations_read" ON public.squad_invitations
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

DROP POLICY IF EXISTS "squad_invitations_insert" ON public.squad_invitations;
CREATE POLICY "squad_invitations_insert" ON public.squad_invitations
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "squad_invitations_update" ON public.squad_invitations;
CREATE POLICY "squad_invitations_update" ON public.squad_invitations
  FOR UPDATE TO authenticated
  USING (
    receiver_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

DROP POLICY IF EXISTS "squad_invitations_delete" ON public.squad_invitations;
CREATE POLICY "squad_invitations_delete" ON public.squad_invitations
  FOR DELETE TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM public.squad_members
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

-- ── calls: caller or callee can view; participants manage ───────
DROP POLICY IF EXISTS "calls_read" ON public.calls;
CREATE POLICY "calls_read" ON public.calls
  FOR SELECT TO authenticated
  USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
  );

DROP POLICY IF EXISTS "calls_insert" ON public.calls;
CREATE POLICY "calls_insert" ON public.calls
  FOR INSERT TO authenticated
  WITH CHECK (caller_id = auth.uid());

DROP POLICY IF EXISTS "calls_update" ON public.calls;
CREATE POLICY "calls_update" ON public.calls
  FOR UPDATE TO authenticated
  USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
  );

DROP POLICY IF EXISTS "calls_delete" ON public.calls;
CREATE POLICY "calls_delete" ON public.calls
  FOR DELETE TO authenticated
  USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
  );

-- ── call_ice_candidates: call participants ──────────────────────
DROP POLICY IF EXISTS "call_ice_candidates_read" ON public.call_ice_candidates;
CREATE POLICY "call_ice_candidates_read" ON public.call_ice_candidates
  FOR SELECT TO authenticated
  USING (
    call_id IN (
      SELECT id FROM public.calls
      WHERE caller_id = auth.uid() OR callee_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "call_ice_candidates_insert" ON public.call_ice_candidates;
CREATE POLICY "call_ice_candidates_insert" ON public.call_ice_candidates
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

-- ── team_calls: team members can view; caller can manage ────────
DROP POLICY IF EXISTS "team_calls_read" ON public.team_calls;
CREATE POLICY "team_calls_read" ON public.team_calls
  FOR SELECT TO authenticated
  USING (
    caller_id = auth.uid()
    OR team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "team_calls_insert" ON public.team_calls;
CREATE POLICY "team_calls_insert" ON public.team_calls
  FOR INSERT TO authenticated
  WITH CHECK (caller_id = auth.uid());

DROP POLICY IF EXISTS "team_calls_update" ON public.team_calls;
CREATE POLICY "team_calls_update" ON public.team_calls
  FOR UPDATE TO authenticated
  USING (caller_id = auth.uid());

-- ── team_call_participants: use RLS from fix_team_call_rls.sql ──

-- ── squad_calls: squad members can view; caller can manage ──────
DROP POLICY IF EXISTS "squad_calls_read" ON public.squad_calls;
CREATE POLICY "squad_calls_read" ON public.squad_calls
  FOR SELECT TO authenticated
  USING (
    caller_id = auth.uid()
    OR squad_id IN (
      SELECT squad_id FROM public.squad_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "squad_calls_insert" ON public.squad_calls;
CREATE POLICY "squad_calls_insert" ON public.squad_calls
  FOR INSERT TO authenticated
  WITH CHECK (caller_id = auth.uid());

DROP POLICY IF EXISTS "squad_calls_update" ON public.squad_calls;
CREATE POLICY "squad_calls_update" ON public.squad_calls
  FOR UPDATE TO authenticated
  USING (caller_id = auth.uid());

-- ── squad_call_participants: use RLS from fix_team_call_rls.sql ──

-- ── notifications: only the receiving user ───────────────────────
DROP POLICY IF EXISTS "notifications_own" ON public.notifications;
CREATE POLICY "notifications_own" ON public.notifications
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── posts: public read; own write ────────────────────────────────
DROP POLICY IF EXISTS "posts_read" ON public.posts;
CREATE POLICY "posts_read" ON public.posts
  FOR SELECT TO authenticated
  USING (visibility = 'public' OR user_id = auth.uid());

DROP POLICY IF EXISTS "posts_insert" ON public.posts;
CREATE POLICY "posts_insert" ON public.posts
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "posts_update" ON public.posts;
CREATE POLICY "posts_update" ON public.posts
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "posts_delete" ON public.posts;
CREATE POLICY "posts_delete" ON public.posts
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── post_comments: public read; own write ────────────────────────
DROP POLICY IF EXISTS "post_comments_read" ON public.post_comments;
CREATE POLICY "post_comments_read" ON public.post_comments
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "post_comments_insert" ON public.post_comments;
CREATE POLICY "post_comments_insert" ON public.post_comments
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "post_comments_delete" ON public.post_comments;
CREATE POLICY "post_comments_delete" ON public.post_comments
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── post_likes: public read; own write ───────────────────────────
DROP POLICY IF EXISTS "post_likes_read" ON public.post_likes;
CREATE POLICY "post_likes_read" ON public.post_likes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "post_likes_insert" ON public.post_likes;
CREATE POLICY "post_likes_insert" ON public.post_likes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "post_likes_delete" ON public.post_likes;
CREATE POLICY "post_likes_delete" ON public.post_likes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── post_comment_likes: public read; own write ───────────────────
DROP POLICY IF EXISTS "post_comment_likes_read" ON public.post_comment_likes;
CREATE POLICY "post_comment_likes_read" ON public.post_comment_likes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "post_comment_likes_insert" ON public.post_comment_likes;
CREATE POLICY "post_comment_likes_insert" ON public.post_comment_likes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "post_comment_likes_delete" ON public.post_comment_likes;
CREATE POLICY "post_comment_likes_delete" ON public.post_comment_likes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── friends: only the two users ──────────────────────────────────
DROP POLICY IF EXISTS "friends_read" ON public.friends;
CREATE POLICY "friends_read" ON public.friends
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR friend_id = auth.uid());

DROP POLICY IF EXISTS "friends_insert" ON public.friends;
CREATE POLICY "friends_insert" ON public.friends
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR friend_id = auth.uid());

DROP POLICY IF EXISTS "friends_delete" ON public.friends;
CREATE POLICY "friends_delete" ON public.friends
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR friend_id = auth.uid());

-- ── profile_favorite_games: public read; own write ───────────────
DROP POLICY IF EXISTS "profile_favorite_games_read" ON public.profile_favorite_games;
CREATE POLICY "profile_favorite_games_read" ON public.profile_favorite_games
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "profile_favorite_games_write" ON public.profile_favorite_games;
CREATE POLICY "profile_favorite_games_write" ON public.profile_favorite_games
  FOR ALL TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- ── reputation_reviews: reviewer and reviewed can read ───────────
DROP POLICY IF EXISTS "reputation_reviews_read" ON public.reputation_reviews;
CREATE POLICY "reputation_reviews_read" ON public.reputation_reviews
  FOR SELECT TO authenticated
  USING (
    reviewer_id = auth.uid()
    OR reviewed_id = auth.uid()
  );

DROP POLICY IF EXISTS "reputation_reviews_insert" ON public.reputation_reviews;
CREATE POLICY "reputation_reviews_insert" ON public.reputation_reviews
  FOR INSERT TO authenticated
  WITH CHECK (reviewer_id = auth.uid());

-- ── devices: own device tokens only ──────────────────────────────
DROP POLICY IF EXISTS "devices_own" ON public.devices;
CREATE POLICY "devices_own" ON public.devices
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── match_events: participants can read ──────────────────────────
DROP POLICY IF EXISTS "match_events_read" ON public.match_events;
CREATE POLICY "match_events_read" ON public.match_events
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR matched_user_id = auth.uid()
  );

DROP POLICY IF EXISTS "match_events_insert" ON public.match_events;
CREATE POLICY "match_events_insert" ON public.match_events
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ── user_progress: own record only ───────────────────────────────
DROP POLICY IF EXISTS "user_progress_own" ON public.user_progress;
CREATE POLICY "user_progress_own" ON public.user_progress
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

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
