-- ============================================================
-- Enrich notification payloads with actor_id, post_id, comment_id
-- and actor_avatar_url for in-app display with pfp + navigation
-- Run: supabase db update
-- ============================================================

-- 1. Post likes: add actor_id, actor_avatar_url, post_id
CREATE OR REPLACE FUNCTION public.notify_push_on_post_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  owner_devices json;
  actor_name text;
  actor_avatar text;
  post_owner_id uuid;
BEGIN
  SELECT p.user_id INTO post_owner_id
  FROM public.posts p
  WHERE p.id = NEW.post_id;

  IF post_owner_id IS NULL OR post_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT pseudo, avatar_url INTO actor_name, actor_avatar
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Insert in-app notification with enriched payload
  BEGIN
    INSERT INTO public.notifications (user_id, type, payload)
    VALUES (
      post_owner_id,
      'post_like',
      json_build_object(
        'title', 'New like',
        'body', actor_name || ' liked your post',
        'actor_id', NEW.user_id,
        'actor_pseudo', actor_name,
        'actor_avatar_url', actor_avatar,
        'post_id', NEW.post_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO owner_devices
  FROM public.devices d
  WHERE d.user_id = post_owner_id;

  IF owner_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'post_like',
        'recipient_id', post_owner_id,
        'sender_id', NEW.user_id,
        'sender_name', actor_name,
        'content', 'liked your post',
        'post_id', NEW.post_id,
        'devices', owner_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 2. Post comments: add actor_id, post_id, comment_id, actor_avatar_url
CREATE OR REPLACE FUNCTION public.notify_push_on_post_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  owner_devices json;
  actor_name text;
  actor_avatar text;
  target_owner_id uuid;
  notif_type text;
  notif_title text;
  notif_body text;
  push_type text;
  push_content text;
BEGIN
  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT pseudo, avatar_url INTO actor_name, actor_avatar
  FROM public.profiles
  WHERE id = NEW.user_id;

  IF NEW.parent_id IS NOT NULL THEN
    SELECT pc.user_id INTO target_owner_id
    FROM public.post_comments pc
    WHERE pc.id = NEW.parent_id;

    notif_type := 'comment_reply';
    notif_title := 'New reply';
    notif_body := actor_name || ' replied to your comment';
    push_type := 'comment_reply';
    push_content := 'replied to your comment';
  ELSE
    SELECT p.user_id INTO target_owner_id
    FROM public.posts p
    WHERE p.id = NEW.post_id;

    notif_type := 'post_comment';
    notif_title := 'New comment';
    notif_body := actor_name || ' commented on your post';
    push_type := 'post_comment';
    push_content := 'commented on your post';
  END IF;

  IF target_owner_id IS NULL OR target_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Insert in-app notification with enriched payload
  BEGIN
    INSERT INTO public.notifications (user_id, type, payload)
    VALUES (
      target_owner_id,
      notif_type,
      json_build_object(
        'title', notif_title,
        'body', notif_body,
        'actor_id', NEW.user_id,
        'actor_pseudo', actor_name,
        'actor_avatar_url', actor_avatar,
        'post_id', NEW.post_id,
        'comment_id', NEW.id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO owner_devices
  FROM public.devices d
  WHERE d.user_id = target_owner_id;

  IF owner_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', push_type,
        'recipient_id', target_owner_id,
        'sender_id', NEW.user_id,
        'sender_name', actor_name,
        'content', push_content,
        'post_id', NEW.post_id,
        'comment_id', NEW.id,
        'devices', owner_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- 3. Comment likes: add actor_id, comment_id, actor_avatar_url
CREATE OR REPLACE FUNCTION public.notify_push_on_comment_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  push_url text;
  owner_devices json;
  actor_name text;
  actor_avatar text;
  comment_owner_id uuid;
  affected_post_id uuid;
BEGIN
  SELECT pc.user_id, pc.post_id INTO comment_owner_id, affected_post_id
  FROM public.post_comments pc
  WHERE pc.id = NEW.comment_id;

  IF comment_owner_id IS NULL OR comment_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  push_url := 'https://edlxuaoldmdabteiqjfa.functions.supabase.co/send-push-notification';

  SELECT pseudo, avatar_url INTO actor_name, actor_avatar
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Insert in-app notification with enriched payload
  BEGIN
    INSERT INTO public.notifications (user_id, type, payload)
    VALUES (
      comment_owner_id,
      'comment_like',
      json_build_object(
        'title', 'New like',
        'body', actor_name || ' liked your comment',
        'actor_id', NEW.user_id,
        'actor_pseudo', actor_name,
        'actor_avatar_url', actor_avatar,
        'post_id', affected_post_id,
        'comment_id', NEW.comment_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT json_agg(json_build_object('token', d.token, 'platform', d.platform))
  INTO owner_devices
  FROM public.devices d
  WHERE d.user_id = comment_owner_id;

  IF owner_devices IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := push_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := json_build_object(
        'type', 'comment_like',
        'recipient_id', comment_owner_id,
        'sender_id', NEW.user_id,
        'sender_name', actor_name,
        'content', 'liked your comment',
        'comment_id', NEW.comment_id,
        'devices', owner_devices
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
