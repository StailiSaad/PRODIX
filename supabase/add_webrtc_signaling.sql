-- WebRTC Signaling schema
-- Run this in your Supabase SQL Editor.

-- Add SDP columns to calls
ALTER TABLE public.calls ADD COLUMN IF NOT EXISTS offer_sdp TEXT;
ALTER TABLE public.calls ADD COLUMN IF NOT EXISTS answer_sdp TEXT;

-- ICE candidates table
CREATE TABLE IF NOT EXISTS public.call_ice_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES public.calls(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id),
  candidate TEXT NOT NULL,
  sdp_mid TEXT,
  sdp_mline_index INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.call_ice_candidates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read ICE candidates for their calls"
  ON public.call_ice_candidates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.calls
      WHERE calls.id = call_ice_candidates.call_id
      AND (calls.caller_id = auth.uid() OR calls.callee_id = auth.uid())
    )
  );

CREATE POLICY "Users can insert their own ICE candidates"
  ON public.call_ice_candidates FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.calls
      WHERE calls.id = call_ice_candidates.call_id
      AND (calls.caller_id = auth.uid() OR calls.callee_id = auth.uid())
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.call_ice_candidates;
