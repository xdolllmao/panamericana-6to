-- =====================================================
-- NOTICIAS del feed: solo Gerardo y Magaña pueden publicar; todos leen.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
create table if not exists public.news (
  id             uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body           text not null check (char_length(body) between 1 and 1000),
  created_at     timestamptz default now()
);
create index if not exists news_created_idx on public.news(created_at desc);
alter table public.news enable row level security;

-- Leer: cualquiera con sesión.
drop policy if exists "news_read" on public.news;
create policy "news_read" on public.news for select using (auth.uid() is not null);

-- Publicar: SOLO perfiles cuyo nombre sea Gerardo o Magaña.
drop policy if exists "news_insert_editors" on public.news;
create policy "news_insert_editors" on public.news for insert with check (
  author_user_id = auth.uid()
  and exists (
    select 1 from public.profiles
    where user_id = auth.uid() and name in ('Gerardo','Magaña')
  )
);

-- Borrar: el propio autor.
drop policy if exists "news_delete_own" on public.news;
create policy "news_delete_own" on public.news for delete using (author_user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='news';
  if not found then alter publication supabase_realtime add table public.news; end if;
end $$;
alter table public.news replica identity full;
