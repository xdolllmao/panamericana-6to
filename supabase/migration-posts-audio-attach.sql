-- =====================================================
-- Adjuntar música/audio a las publicaciones (foto, reel, opinión) del feed,
-- igual que en las historias.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
alter table public.posts add column if not exists audio_url   text;
alter table public.posts add column if not exists audio_title text;
alter table public.posts add column if not exists audio_cover text;
