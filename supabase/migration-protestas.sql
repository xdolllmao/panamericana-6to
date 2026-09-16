-- =====================================================
-- PROTESTAS: muro de protestas con categorías, solución opcional,
-- like / dislike / comentarios. El autor elige anónimo o con su nombre.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
create table if not exists public.protests (
  id             uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body           text not null check (char_length(body) between 1 and 500),
  solution       text check (solution is null or char_length(solution) <= 400),
  categories     text[] not null default '{}',
  anonymous      boolean not null default true,
  author_name    text,
  created_at     timestamptz default now()
);
create index if not exists protests_created_idx on public.protests(created_at desc);
alter table public.protests enable row level security;
drop policy if exists "protests_read" on public.protests;
create policy "protests_read" on public.protests for select using (auth.uid() is not null);
drop policy if exists "protests_insert_own" on public.protests;
create policy "protests_insert_own" on public.protests for insert with check (
  author_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "protests_delete_own" on public.protests;
create policy "protests_delete_own" on public.protests for delete using (author_user_id = auth.uid());

-- ---- likes ----
create table if not exists public.protest_likes (
  protest_id uuid not null references public.protests(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (protest_id, user_id)
);
create index if not exists protest_likes_idx on public.protest_likes(protest_id);
alter table public.protest_likes enable row level security;
drop policy if exists "protest_likes_read" on public.protest_likes;
create policy "protest_likes_read" on public.protest_likes for select using (auth.uid() is not null);
drop policy if exists "protest_likes_insert" on public.protest_likes;
create policy "protest_likes_insert" on public.protest_likes for insert with check (
  user_id = auth.uid() and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "protest_likes_delete" on public.protest_likes;
create policy "protest_likes_delete" on public.protest_likes for delete using (user_id = auth.uid());

-- ---- dislikes ----
create table if not exists public.protest_dislikes (
  protest_id uuid not null references public.protests(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (protest_id, user_id)
);
create index if not exists protest_dislikes_idx on public.protest_dislikes(protest_id);
alter table public.protest_dislikes enable row level security;
drop policy if exists "protest_dislikes_read" on public.protest_dislikes;
create policy "protest_dislikes_read" on public.protest_dislikes for select using (auth.uid() is not null);
drop policy if exists "protest_dislikes_insert" on public.protest_dislikes;
create policy "protest_dislikes_insert" on public.protest_dislikes for insert with check (
  user_id = auth.uid() and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "protest_dislikes_delete" on public.protest_dislikes;
create policy "protest_dislikes_delete" on public.protest_dislikes for delete using (user_id = auth.uid());

-- ---- comentarios (anónimos) ----
create table if not exists public.protest_comments (
  id             uuid primary key default gen_random_uuid(),
  protest_id     uuid not null references public.protests(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  text           text not null check (char_length(text) between 1 and 240),
  created_at     timestamptz default now()
);
create index if not exists protest_comments_idx on public.protest_comments(protest_id, created_at);
alter table public.protest_comments enable row level security;
drop policy if exists "protest_comments_read" on public.protest_comments;
create policy "protest_comments_read" on public.protest_comments for select using (auth.uid() is not null);
drop policy if exists "protest_comments_insert" on public.protest_comments;
create policy "protest_comments_insert" on public.protest_comments for insert with check (
  author_user_id = auth.uid() and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "protest_comments_delete" on public.protest_comments;
create policy "protest_comments_delete" on public.protest_comments for delete using (author_user_id = auth.uid());

-- ---- realtime ----
do $$
begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='protests';
  if not found then alter publication supabase_realtime add table public.protests; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='protest_likes';
  if not found then alter publication supabase_realtime add table public.protest_likes; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='protest_dislikes';
  if not found then alter publication supabase_realtime add table public.protest_dislikes; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='protest_comments';
  if not found then alter publication supabase_realtime add table public.protest_comments; end if;
end $$;
alter table public.protests          replica identity full;
alter table public.protest_likes     replica identity full;
alter table public.protest_dislikes  replica identity full;
alter table public.protest_comments  replica identity full;
