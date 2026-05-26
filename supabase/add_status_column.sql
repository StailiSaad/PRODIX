-- Add status column to messages table if missing
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'sent';

-- Refresh PostgREST schema cache so it recognizes the column immediately
NOTIFY pgrst, 'reload schema';
