-- =====================================================
-- Ships: solo el autor puede borrar
-- =====================================================
-- Agrega columna author_user_id (nullable para ships viejos).
alter table public.ships
  add column if not exists author_user_id uuid references auth.users(id) on delete cascade;

-- Ahora el insert exige que el author_user_id coincida con el auth.uid()
drop policy if exists "ships_insert" on public.ships;
create policy "ships_insert" on public.ships
  for insert with check (
    author_user_id = auth.uid()
    and exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Borrar: solo el creador. Los ships viejos con author_user_id NULL quedan
-- sin poder borrarse desde la app; si querés limpiarlos, hacelo desde SQL.
drop policy if exists "ships_delete" on public.ships;
create policy "ships_delete" on public.ships
  for delete using (author_user_id = auth.uid());
