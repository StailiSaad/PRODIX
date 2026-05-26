-- Team Calls schema for group calls
-- Run this in your Supabase SQL Editor.

-- Team calls: groups multiple participants into one call room
CREATE TABLE IF NOT EXISTS public.team_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  caller_id UUID NOT NULL REFERENCES public.profiles(id),
  call_type TEXT NOT NULL DEFAULT 'audio',
  status TEXT NOT NULL DEFAULT 'ringing',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

ALTER TABLE public.team_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Team members can view team calls" ON public.team_calls;
CREATE POLICY "Team members can view team calls"
  ON public.team_calls FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = team_calls.team_id
      AND team_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Team members can start team calls" ON public.team_calls;
CREATE POLICY "Team members can start team calls"
  ON public.team_calls FOR INSERT
  WITH CHECK (
    caller_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = team_calls.team_id
      AND team_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Caller can update their team calls" ON public.team_calls;
CREATE POLICY "Caller can update their team calls"
  ON public.team_calls FOR UPDATE
  USING (caller_id = auth.uid())
  WITH CHECK (caller_id = auth.uid());

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.team_calls;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Participants in a team call
CREATE TABLE IF NOT EXISTS public.team_call_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES public.team_calls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  status TEXT NOT NULL DEFAULT 'ringing',
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  offer_sdp TEXT,
  answer_sdp TEXT
);

ALTER TABLE public.team_call_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own participation" ON public.team_call_participants;
CREATE POLICY "Users can view their own participation"
  ON public.team_call_participants FOR SELECT
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.team_calls
      WHERE team_calls.id = call_id
      AND team_calls.caller_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Caller can add participants" ON public.team_call_participants;
CREATE POLICY "Caller can add participants"
  ON public.team_call_participants FOR INSERT
  WITH CHECK (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.team_calls
      WHERE team_calls.id = call_id
      AND team_calls.caller_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own participation" ON public.team_call_participants;
CREATE POLICY "Users can update their own participation"
  ON public.team_call_participants FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Caller can update participant SDP" ON public.team_call_participants;
CREATE POLICY "Caller can update participant SDP"
  ON public.team_call_participants FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.team_calls
      WHERE team_calls.id = call_id
      AND team_calls.caller_id = auth.uid()
    )
  );

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.team_call_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ICE candidates for team calls (per participant pair)
CREATE TABLE IF NOT EXISTS public.team_call_ice_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id UUID NOT NULL REFERENCES public.team_call_participants(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  candidate TEXT NOT NULL,
  sdp_mid TEXT,
  sdp_mline_index INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.team_call_ice_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read ICE candidates for their team calls" ON public.team_call_ice_candidates;
CREATE POLICY "Users can read ICE candidates for their team calls"
  ON public.team_call_ice_candidates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_call_participants
      WHERE team_call_participants.id = team_call_ice_candidates.participant_id
      AND (team_call_participants.user_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM public.team_calls
          WHERE team_calls.id = team_call_participants.call_id
          AND team_calls.caller_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can insert their own ICE candidates" ON public.team_call_ice_candidates;
CREATE POLICY "Users can insert their own ICE candidates"
  ON public.team_call_ice_candidates FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.team_call_participants
      WHERE team_call_participants.id = team_call_ice_candidates.participant_id
      AND (team_call_participants.user_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM public.team_calls
          WHERE team_calls.id = team_call_participants.call_id
          AND team_calls.caller_id = auth.uid()
        )
      )
    )
  );

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.team_call_ice_candidates;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
