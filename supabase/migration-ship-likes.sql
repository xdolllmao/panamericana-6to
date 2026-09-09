-- =====================================================
-- Likes anonimos para ships
-- =====================================================
create table if not exists public.ship_likes (
  ship_id    uuid not null references public.ships(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (ship_id, user_id)
);

create index if not exists ship_likes_ship_idx on public.ship_likes(ship_id);

alter table public.ship_likes enable row level security;

-- Lectura: cualquiera puede saber CUANTOS likes tiene un ship (para el contador),
-- pero al frontend no mostramos quien fue (anonimo).
drop policy if exists "ship_likes_read" on public.ship_likes;
create policy "ship_likes_read" on public.ship_likes
  for select using (auth.uid() is not null);

-- Solo usuarios con perfil pueden dar like, y solo pueden crear su propia fila.
drop policy if exists "ship_likes_insert" on public.ship_likes;
create policy "ship_likes_insert" on public.ship_likes
  for insert with check (
    user_id = auth.uid()
    and exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Solo pueden quitar SU propio like.
drop policy if exists "ship_likes_delete" on public.ship_likes;
create policy "ship_likes_delete" on public.ship_likes
  for delete using (user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ship_likes';
  if not found then
    alter publication supabase_realtime add table public.ship_likes;
  end if;
end $$;

alter table public.ship_likes replica identity full;
