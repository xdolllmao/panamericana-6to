-- =====================================================
-- Lista de canciones de la semana (anónima, máx 10, con likes)
-- La "semana" es una etiqueta ISO (ej. 2026-W37) que calcula el cliente;
-- cada semana nueva la lista arranca vacía sin borrar el historial.
-- =====================================================
create table if not exists public.songs (
  id             uuid primary key default gen_random_uuid(),
  week           text not null,
  spotify_id     text not null,
  name           text not null,
  artists        text not null,
  cover_url      text,
  spotify_url    text not null,
  author_user_id uuid references auth.users(id) on delete set null,
  created_at     timestamptz default now(),
  unique (week, spotify_id)
);
create index if not exists songs_week_idx on public.songs(week);

create table if not exists public.song_likes (
  song_id    uuid not null references public.songs(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (song_id, user_id)
);
create index if not exists song_likes_song_idx on public.song_likes(song_id);

alter table public.songs enable row level security;
alter table public.song_likes enable row level security;

-- Lectura para cualquier authenticated (incluye anon de Supabase)
drop policy if exists "songs_read" on public.songs;
create policy "songs_read" on public.songs for select using (auth.uid() is not null);
drop policy if exists "song_likes_read" on public.song_likes;
create policy "song_likes_read" on public.song_likes for select using (auth.uid() is not null);

-- Insertar canción: perfil requerido, autor = uid, y menos de 10 en esa semana.
-- La subconsulta cuenta las canciones existentes de la MISMA semana de la fila nueva.
drop policy if exists "songs_insert" on public.songs;
create policy "songs_insert" on public.songs for insert with check (
  author_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
  and (select count(*) from public.songs s where s.week = songs.week) < 10
);

-- Cada quien puede borrar SU propia canción (anónimo hacia afuera igual).
drop policy if exists "songs_delete_own" on public.songs;
create policy "songs_delete_own" on public.songs for delete using (author_user_id = auth.uid());

-- Likes: solo perfiles, solo tu propia fila.
drop policy if exists "song_likes_insert" on public.song_likes;
create policy "song_likes_insert" on public.song_likes for insert with check (
  user_id = auth.uid() and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "song_likes_delete" on public.song_likes;
create policy "song_likes_delete" on public.song_likes for delete using (user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='songs';
  if not found then alter publication supabase_realtime add table public.songs; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='song_likes';
  if not found then alter publication supabase_realtime add table public.song_likes; end if;
end $$;
alter table public.songs replica identity full;
alter table public.song_likes replica identity full;
