-- =====================================================
-- Desactivar el borrado de contenido para los usuarios.
-- Nadie puede borrar mensajes, publicaciones, historias, ships,
-- protestas, comentarios ni canciones desde la app.
-- (Vos como admin SÍ podés borrar desde el SQL Editor, porque el
-- service_role ignora RLS.)
-- NO se tocan los delete de likes/dislikes/follows/votos/flores, porque
-- esos "delete" se usan para des-marcar (quitar tu like, etc.).
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================

-- mensajes del chat
drop policy if exists "messages_delete_own" on public.messages;
drop policy if exists "messages_delete" on public.messages;

-- feed: publicaciones y comentarios
drop policy if exists "posts_delete_own" on public.posts;
drop policy if exists "comments_delete_own" on public.post_comments;

-- historias
drop policy if exists "stories_delete_own" on public.stories;
drop policy if exists "stories_delete" on public.stories;

-- ships y sus comentarios
drop policy if exists "ships_delete" on public.ships;
drop policy if exists "ships_delete_own" on public.ships;
drop policy if exists "ship_comments_delete" on public.ship_comments;

-- protestas y sus comentarios
drop policy if exists "protests_delete_own" on public.protests;
drop policy if exists "protest_comments_delete" on public.protest_comments;

-- música
drop policy if exists "songs_delete_own" on public.songs;
drop policy if exists "songs_delete" on public.songs;
