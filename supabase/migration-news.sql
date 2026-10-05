-- =====================================================
-- ÚLTIMAS NOTICIAS (tablón oficial del salón)
-- Solo los perfiles "Magaña" y "Gerardo" pueden publicar.
-- Todos los que tengan cuenta pueden leer.
-- Límite de 1000 caracteres por noticia. Se muestra CON el nombre
-- del autor (no es anónimo).
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================

create table if not exists public.news (
  id             uuid primary key default gen_random_uuid(),
  author_user_id uuid references auth.users(id) on delete set null,
  author_name    text,
  text           text not null check (char_length(text) <= 1000 and char_length(text) > 0),
  created_at     timestamptz default now()
);
create index if not exists news_created_idx on public.news(created_at desc);

alter table public.news enable row level security;

-- Leer: cualquier usuario con sesión (todos entran como anon user).
drop policy if exists "news_read" on public.news;
create policy "news_read" on public.news
  for select using (auth.uid() is not null);

-- Publicar: SOLO si mi perfil reclamado es "Magaña" o "Gerardo".
drop policy if exists "news_insert" on public.news;
create policy "news_insert" on public.news
  for insert with check (
    author_user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.name in ('Magaña', 'Gerardo')
    )
  );

-- (sin update/delete desde la app; para borrar/corregir una noticia,
--  hacelo desde el SQL Editor con el service_role.)

-- ---- realtime ----
alter table public.news replica identity full;
do $$
begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='news';
  if not found then alter publication supabase_realtime add table public.news; end if;
end $$;
