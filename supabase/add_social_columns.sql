ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_instagram text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_facebook text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS social_github text DEFAULT '';
NOTIFY pgrst, 'reload schema';
