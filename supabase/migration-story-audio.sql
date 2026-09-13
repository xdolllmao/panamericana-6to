-- =====================================================
-- Audio adjunto a las historias
--   Permite ponerle una canción (preview) o un audio propio a
--   cualquier historia (opinión, foto o reel).
--   audio_url guarda la URL + fragmento #t=inicio,fin (recorte, máx 30s).
-- =====================================================
alter table public.stories add column if not exists audio_url   text;
alter table public.stories add column if not exists audio_title text;
alter table public.stories add column if not exists audio_cover text;
