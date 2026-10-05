-- =====================================================
-- Reactivar el borrado SOLO en el feed: cada quien puede borrar
-- SUS propias publicaciones (posts) e historias (stories).
-- El resto (mensajes, ships, protestas, chismes, música) sigue
-- SIN borrado — ver migration-no-delete.sql.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================

-- Publicaciones del feed
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts
  for delete using (author_user_id = auth.uid());

-- Historias del feed
drop policy if exists "stories_delete_own" on public.stories;
create policy "stories_delete_own" on public.stories
  for delete using (author_user_id = auth.uid());
