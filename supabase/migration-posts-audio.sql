-- =====================================================
-- Permitir publicaciones de tipo 'audio' en el feed.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
alter table public.posts drop constraint if exists posts_type_check;
alter table public.posts add constraint posts_type_check
  check (type in ('reel','photo','opinion','audio'));
