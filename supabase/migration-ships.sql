-- =====================================================
-- SHIPS — muro anónimo tipo "Nombre + Nombre"
-- =====================================================
create table if not exists public.ships (
  id         uuid primary key default gen_random_uuid(),
  a          text not null check (char_length(a) between 1 and 24),
  b          text not null check (char_length(b) between 1 and 24),
  created_at timestamptz default now()
);

alter table public.ships enable row level security;

-- Cualquier authenticated user (incluye anonimos de Supabase) puede leer.
drop policy if exists "ships_read" on public.ships;
create policy "ships_read" on public.ships
  for select using (auth.uid() is not null);

-- Solo usuarios con perfil claimado pueden publicar.
drop policy if exists "ships_insert" on public.ships;
create policy "ships_insert" on public.ships
  for insert with check (
    exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Cualquier usuario con perfil puede borrar (los ships son publicos y anonimos,
-- asi que la moderacion es abierta como en el resto del sitio).
drop policy if exists "ships_delete" on public.ships;
create policy "ships_delete" on public.ships
  for delete using (
    exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Realtime: agregar tabla al publication.
do $$ begin
  perform 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ships';
  if not found then
    alter publication supabase_realtime add table public.ships;
  end if;
end $$;

-- Necesario para que los eventos DELETE lleguen con el id (no solo con la PK).
alter table public.ships replica identity full;
