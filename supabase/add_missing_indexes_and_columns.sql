-- Add squad_id column to teams table for team-squad linking
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'teams') THEN
    EXECUTE 'ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS squad_id uuid REFERENCES public.squads(id) ON DELETE SET NULL';
  END IF;
END $$;

-- Helper: create index only if table and column both exist
CREATE OR REPLACE FUNCTION _prodix_create_index_if_exists(idx_name text, tbl text, col text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = tbl AND column_name = col
  ) THEN
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I (%I)', idx_name, tbl, col);
  END IF;
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_profiles_pseudo', 'profiles', 'pseudo');
  PERFORM _prodix_create_index_if_exists('idx_profiles_game_type', 'profiles', 'game_type');
  PERFORM _prodix_create_index_if_exists('idx_profiles_region', 'profiles', 'region');
  PERFORM _prodix_create_index_if_exists('idx_profiles_availability', 'profiles', 'availability');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_messages_receiver_id', 'messages', 'receiver_id');
  PERFORM _prodix_create_index_if_exists('idx_messages_sender_id', 'messages', 'sender_id');
  PERFORM _prodix_create_index_if_exists('idx_messages_channel_id', 'messages', 'channel_id');
  PERFORM _prodix_create_index_if_exists('idx_messages_created_at', 'messages', 'created_at');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_team_members_user_id', 'team_members', 'user_id');
  PERFORM _prodix_create_index_if_exists('idx_team_members_team_id', 'team_members', 'team_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_squad_members_user_id', 'squad_members', 'user_id');
  PERFORM _prodix_create_index_if_exists('idx_squad_members_squad_id', 'squad_members', 'squad_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_invitations_receiver_id', 'invitations', 'receiver_id');
  PERFORM _prodix_create_index_if_exists('idx_invitations_sender_id', 'invitations', 'sender_id');
  PERFORM _prodix_create_index_if_exists('idx_invitations_status', 'invitations', 'status');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_friends_user_id', 'friends', 'user_id');
  PERFORM _prodix_create_index_if_exists('idx_friends_friend_id', 'friends', 'friend_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_notifications_user_id', 'notifications', 'user_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_calls_caller_id', 'calls', 'caller_id');
  PERFORM _prodix_create_index_if_exists('idx_calls_callee_id', 'calls', 'callee_id');
  PERFORM _prodix_create_index_if_exists('idx_calls_status', 'calls', 'status');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_call_ice_candidates_call_id', 'call_ice_candidates', 'call_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_team_calls_team_id', 'team_calls', 'team_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_team_call_participants_call_id', 'team_call_participants', 'call_id');
  PERFORM _prodix_create_index_if_exists('idx_team_call_participants_user_id', 'team_call_participants', 'user_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_team_call_ice_candidates_participant_id', 'team_call_ice_candidates', 'participant_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_squad_calls_squad_id', 'squad_calls', 'squad_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_squad_call_participants_call_id', 'squad_call_participants', 'call_id');
  PERFORM _prodix_create_index_if_exists('idx_squad_call_participants_user_id', 'squad_call_participants', 'user_id');
END $$;

DO $$ BEGIN
  PERFORM _prodix_create_index_if_exists('idx_profile_favorite_games_profile_id', 'profile_favorite_games', 'profile_id');
END $$;

-- Drop the temporary helper function
DROP FUNCTION IF EXISTS _prodix_create_index_if_exists;

-- Add realtime for invitations table so we can replace polling with subscriptions
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'invitations') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = 'invitations'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.invitations;
    END IF;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
