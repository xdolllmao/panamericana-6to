-- =====================================================
-- Mensajes de audio en el chat
-- =====================================================
alter table public.messages add column if not exists audio_url text;

-- Ampliar el CHECK para permitir mensajes que solo tengan audio
-- (antes exigia texto o foto).
alter table public.messages drop constraint if exists messages_check;
alter table public.messages
  add constraint messages_check
  check (text is not null or photo_url is not null or audio_url is not null);
