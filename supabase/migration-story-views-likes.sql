-- =====================================================
-- Vistas y likes de historias
--   story_views: quién vio cada historia (solo el dueño lo ve)
--   story_likes: quién dio like (el dueño ve quién; cada quien ve su propio like)
-- =====================================================
create table if not exists public.story_views (
  story_id       uuid not null references public.stories(id) on delete cascade,
  viewer_user_id uuid not null references auth.users(id) on delete cascade,
  created_at     timestamptz default now(),
  primary key (story_id, viewer_user_id)
);
create index if not exists story_views_story_idx on public.story_views(story_id);

create table if not exists public.story_likes (
  story_id   uuid not null references public.stories(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (story_id, user_id)
);
create index if not exists story_likes_story_idx on public.story_likes(story_id);

alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

-- ---- story_views ----
-- Ver: solo el DUEÑO de la historia (o el propio viewer) puede leer las vistas.
drop policy if exists "story_views_read" on public.story_views;
create policy "story_views_read" on public.story_views for select using (
  viewer_user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_id and s.author_user_id = auth.uid())
);
-- Insertar: registro MI propia vista, y necesito tener perfil.
drop policy if exists "story_views_insert" on public.story_views;
create policy "story_views_insert" on public.story_views for insert with check (
  viewer_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);

-- ---- story_likes ----
-- Ver: mi propio like (para saber si di like) o el dueño de la historia (ve todos).
drop policy if exists "story_likes_read" on public.story_likes;
create policy "story_likes_read" on public.story_likes for select using (
  user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_id and s.author_user_id = auth.uid())
);
drop policy if exists "story_likes_insert" on public.story_likes;
create policy "story_likes_insert" on public.story_likes for insert with check (
  user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "story_likes_delete" on public.story_likes;
create policy "story_likes_delete" on public.story_likes for delete using (user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='story_views';
  if not found then alter publication supabase_realtime add table public.story_views; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='story_likes';
  if not found then alter publication supabase_realtime add table public.story_likes; end if;
end $$;
alter table public.story_views replica identity full;
alter table public.story_likes replica identity full;
