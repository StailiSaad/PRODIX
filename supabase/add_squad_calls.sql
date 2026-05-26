-- Squad Calls schema for group calls in squad chat
-- Run this in your Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.squad_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  caller_id UUID NOT NULL REFERENCES public.profiles(id),
  call_type TEXT NOT NULL DEFAULT 'audio',
  status TEXT NOT NULL DEFAULT 'ringing',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

ALTER TABLE public.squad_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Squad members can view squad calls" ON public.squad_calls;
CREATE POLICY "Squad members can view squad calls"
  ON public.squad_calls FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.squad_members
      WHERE squad_members.squad_id = squad_calls.squad_id
      AND squad_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Squad members can start squad calls" ON public.squad_calls;
CREATE POLICY "Squad members can start squad calls"
  ON public.squad_calls FOR INSERT
  WITH CHECK (
    caller_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.squad_members
      WHERE squad_members.squad_id = squad_calls.squad_id
      AND squad_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Caller can update their squad calls" ON public.squad_calls;
CREATE POLICY "Caller can update their squad calls"
  ON public.squad_calls FOR UPDATE
  USING (caller_id = auth.uid())
  WITH CHECK (caller_id = auth.uid());

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.squad_calls;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.squad_call_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES public.squad_calls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  status TEXT NOT NULL DEFAULT 'ringing',
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  offer_sdp TEXT,
  answer_sdp TEXT
);

ALTER TABLE public.squad_call_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own squad participation" ON public.squad_call_participants;
CREATE POLICY "Users can view their own squad participation"
  ON public.squad_call_participants FOR SELECT
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.squad_calls
      WHERE squad_calls.id = call_id
      AND squad_calls.caller_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Caller can add squad participants" ON public.squad_call_participants;
CREATE POLICY "Caller can add squad participants"
  ON public.squad_call_participants FOR INSERT
  WITH CHECK (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.squad_calls
      WHERE squad_calls.id = call_id
      AND squad_calls.caller_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own squad participation" ON public.squad_call_participants;
CREATE POLICY "Users can update their own squad participation"
  ON public.squad_call_participants FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Caller can update squad participant SDP" ON public.squad_call_participants;
CREATE POLICY "Caller can update squad participant SDP"
  ON public.squad_call_participants FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.squad_calls
      WHERE squad_calls.id = call_id
      AND squad_calls.caller_id = auth.uid()
    )
  );

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.squad_call_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.squad_call_ice_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id UUID NOT NULL REFERENCES public.squad_call_participants(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  candidate TEXT NOT NULL,
  sdp_mid TEXT,
  sdp_mline_index INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.squad_call_ice_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read ICE candidates for their squad calls" ON public.squad_call_ice_candidates;
CREATE POLICY "Users can read ICE candidates for their squad calls"
  ON public.squad_call_ice_candidates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.squad_call_participants
      WHERE squad_call_participants.id = squad_call_ice_candidates.participant_id
      AND (squad_call_participants.user_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM public.squad_calls
          WHERE squad_calls.id = squad_call_participants.call_id
          AND squad_calls.caller_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can insert their own squad ICE candidates" ON public.squad_call_ice_candidates;
CREATE POLICY "Users can insert their own squad ICE candidates"
  ON public.squad_call_ice_candidates FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.squad_call_participants
      WHERE squad_call_participants.id = squad_call_ice_candidates.participant_id
      AND (squad_call_participants.user_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM public.squad_calls
          WHERE squad_calls.id = squad_call_participants.call_id
          AND squad_calls.caller_id = auth.uid()
        )
      )
    )
  );

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.squad_call_ice_candidates;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
