-- ============================================================
-- Fix RLS on team_call_participants / squad_call_participants
-- Avoids infinite recursion by querying team_calls/squad_calls
-- instead of self-referencing.
-- ============================================================

DROP POLICY IF EXISTS "Users can view their own participation" ON public.team_call_participants;
DROP POLICY IF EXISTS "Users can view their own squad participation" ON public.squad_call_participants;
DROP POLICY IF EXISTS "Participants can view call participants" ON public.team_call_participants;
DROP POLICY IF EXISTS "Participants can view squad call participants" ON public.squad_call_participants;

CREATE POLICY "Participants can view call participants"
  ON public.team_call_participants FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    call_id IN (
      SELECT tc.id FROM public.team_calls tc
      WHERE tc.team_id IN (
        SELECT tm.team_id FROM public.team_members tm WHERE tm.user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Participants can view squad call participants"
  ON public.squad_call_participants FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    call_id IN (
      SELECT sc.id FROM public.squad_calls sc
      WHERE sc.squad_id IN (
        SELECT sm.squad_id FROM public.squad_members sm WHERE sm.user_id = auth.uid()
      )
    )
  );
