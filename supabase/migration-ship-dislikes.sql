-- =====================================================
-- Dislikes anónimos para ships (mismo patrón que ship_likes)
-- =====================================================
create table if not exists public.ship_dislikes (
  ship_id    uuid not null references public.ships(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (ship_id, user_id)
);

create index if not exists ship_dislikes_ship_idx on public.ship_dislikes(ship_id);

alter table public.ship_dislikes enable row level security;

-- Lectura: cualquiera con sesión puede saber CUÁNTOS dislikes tiene un ship
-- (para el contador), pero al frontend no mostramos quién fue (anónimo).
drop policy if exists "ship_dislikes_read" on public.ship_dislikes;
create policy "ship_dislikes_read" on public.ship_dislikes
  for select using (auth.uid() is not null);

-- Solo usuarios con perfil pueden dar dislike, y solo su propia fila.
drop policy if exists "ship_dislikes_insert" on public.ship_dislikes;
create policy "ship_dislikes_insert" on public.ship_dislikes
  for insert with check (
    user_id = auth.uid()
    and exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Solo pueden quitar SU propio dislike.
drop policy if exists "ship_dislikes_delete" on public.ship_dislikes;
create policy "ship_dislikes_delete" on public.ship_dislikes
  for delete using (user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ship_dislikes';
  if not found then
    alter publication supabase_realtime add table public.ship_dislikes;
  end if;
end $$;

alter table public.ship_dislikes replica identity full;
