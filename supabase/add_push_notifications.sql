-- ============================================================
-- Push notifications schema for Prodix
-- Run this ONCE via: supabase db query --linked -f <thisfile>
-- ============================================================

-- 0. Enable pg_net extension for HTTP requests from DB triggers
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. Devices table: stores FCM tokens per user
CREATE TABLE IF NOT EXISTS public.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'android',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own devices" ON public.devices;
CREATE POLICY "Users can manage their own devices"
  ON public.devices FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_devices_user_id ON public.devices (user_id);

-- 2. Function to notify the Edge Function when a new message is inserted
--    The Edge Function URL must be set via: ALTER DATABASE postgres SET app.push_url TO 'https://<project>.functions.supabase.co/send-push-notification';
CREATE OR REPLACE FUNCTION public.notify_push_on_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  receiver_devices json;
  sender_name text;
BEGIN
  -- Only notify for DMs (receiver_id set), not channel messages
  IF NEW.receiver_id IS NULL THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT p.pseudo INTO sender_name
  FROM public.profiles p
  WHERE p.id = NEW.sender_id;

  -- Gather FCM tokens for the receiver
  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO receiver_devices
  FROM public.devices d
  WHERE d.user_id = NEW.receiver_id;

  IF receiver_devices IS NULL THEN
    RETURN NEW;
  END IF;

  -- Call the Edge Function asynchronously via pg_net (net.http_post)
  -- Requires: supabase addons pg_net
  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'message',
        'recipient_id', NEW.receiver_id,
        'sender_id', NEW.sender_id,
        'sender_name', sender_name,
        'content', LEFT(NEW.content, 200),
        'devices', receiver_devices,
        'message_id', NEW.id
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    -- pg_net may not be installed; silently skip
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 3. Function to notify on incoming call
CREATE OR REPLACE FUNCTION public.notify_push_on_call()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  callee_devices json;
  caller_name text;
BEGIN
  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT p.pseudo INTO caller_name
  FROM public.profiles p
  WHERE p.id = NEW.caller_id;

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO callee_devices
  FROM public.devices d
  WHERE d.user_id = NEW.callee_id;

  IF callee_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'call',
        'recipient_id', NEW.callee_id,
        'caller_id', NEW.caller_id,
        'caller_name', caller_name,
        'call_type', NEW.call_type,
        'call_id', NEW.id,
        'devices', callee_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 4. Function to notify on invitation
CREATE OR REPLACE FUNCTION public.notify_push_on_invitation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  receiver_devices json;
BEGIN
  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO receiver_devices
  FROM public.devices d
  WHERE d.user_id = NEW.receiver_id;

  IF receiver_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'invitation',
        'recipient_id', NEW.receiver_id,
        'sender_id', NEW.sender_id,
        'invitation_id', NEW.id,
        'devices', receiver_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 5. Function to notify on team call participant (ringing status)
CREATE OR REPLACE FUNCTION public.notify_push_on_team_call_participant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  participant_devices json;
  team_call record;
  caller_profile record;
BEGIN
  IF NEW.status <> 'ringing' THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO participant_devices
  FROM public.devices d
  WHERE d.user_id = NEW.user_id;

  IF participant_devices IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get call details and caller name
  SELECT tc.*, p.pseudo AS caller_name
  INTO team_call
  FROM public.team_calls tc
  LEFT JOIN public.profiles p ON p.id = tc.caller_id
  WHERE tc.id = NEW.call_id;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'call',
        'recipient_id', NEW.user_id,
        'caller_id', team_call.caller_id,
        'caller_name', team_call.caller_name,
        'call_type', team_call.call_type,
        'call_id', team_call.id,
        'group_name', (SELECT name FROM public.teams WHERE id = team_call.team_id),
        'team_id', team_call.team_id,
        'devices', participant_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 6. Function to notify on squad call participant (ringing status)
CREATE OR REPLACE FUNCTION public.notify_push_on_squad_call_participant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  participant_devices json;
  squad_call record;
BEGIN
  IF NEW.status <> 'ringing' THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO participant_devices
  FROM public.devices d
  WHERE d.user_id = NEW.user_id;

  IF participant_devices IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT sc.*, p.pseudo AS caller_name
  INTO squad_call
  FROM public.squad_calls sc
  LEFT JOIN public.profiles p ON p.id = sc.caller_id
  WHERE sc.id = NEW.call_id;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'call',
        'recipient_id', NEW.user_id,
        'caller_id', squad_call.caller_id,
        'caller_name', squad_call.caller_name,
        'call_type', squad_call.call_type,
        'call_id', squad_call.id,
        'group_name', (SELECT name FROM public.squads WHERE id = squad_call.squad_id),
        'squad_id', squad_call.squad_id,
        'devices', participant_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 7. Function to notify on missed call (when caller hangs up while callee is ringing)
CREATE OR REPLACE FUNCTION public.notify_missed_call_on_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  callee_devices json;
  caller_name text;
BEGIN
  -- Only fire when status changes from 'ringing' to a non-connected state
  IF OLD.status <> 'ringing' OR NEW.status IN ('ringing', 'connected') THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT p.pseudo INTO caller_name
  FROM public.profiles p
  WHERE p.id = NEW.caller_id;

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO callee_devices
  FROM public.devices d
  WHERE d.user_id = NEW.callee_id;

  IF callee_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'missed_call',
        'recipient_id', NEW.callee_id,
        'caller_id', NEW.caller_id,
        'caller_name', caller_name,
        'call_id', NEW.id,
        'devices', callee_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 8. Helper: create trigger only if the table exists
CREATE OR REPLACE FUNCTION _prodix_create_trigger_if_table_exists(
  trigger_name text,
  table_name text,
  func_name text
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = table_name) THEN
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', trigger_name, table_name);
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%I()',
      trigger_name, table_name, func_name
    );
  END IF;
END $$;

SELECT _prodix_create_trigger_if_table_exists('trg_notify_push_message', 'messages', 'notify_push_on_message');
SELECT _prodix_create_trigger_if_table_exists('trg_notify_push_call', 'calls', 'notify_push_on_call');
SELECT _prodix_create_trigger_if_table_exists('trg_notify_push_invitation', 'invitations', 'notify_push_on_invitation');
SELECT _prodix_create_trigger_if_table_exists('trg_notify_push_team_call', 'team_call_participants', 'notify_push_on_team_call_participant');
SELECT _prodix_create_trigger_if_table_exists('trg_notify_push_squad_call', 'squad_call_participants', 'notify_push_on_squad_call_participant');

SELECT _prodix_create_trigger_if_table_exists('trg_notify_missed_call', 'calls', 'notify_missed_call_on_update');
-- For missed calls, we need an UPDATE trigger instead of INSERT
DROP TRIGGER IF EXISTS trg_notify_missed_call ON public.calls;
CREATE TRIGGER trg_notify_missed_call
  AFTER UPDATE OF status ON public.calls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_missed_call_on_update();

DROP FUNCTION IF EXISTS _prodix_create_trigger_if_table_exists;

NOTIFY pgrst, 'reload schema';
