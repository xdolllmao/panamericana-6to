-- =====================================================
-- Comentarios anonimos para ships
-- =====================================================
create table if not exists public.ship_comments (
  id              uuid primary key default gen_random_uuid(),
  ship_id         uuid not null references public.ships(id) on delete cascade,
  author_user_id  uuid references auth.users(id) on delete set null,
  text            text not null check (char_length(text) between 1 and 240),
  created_at      timestamptz default now()
);

create index if not exists ship_comments_ship_idx on public.ship_comments(ship_id, created_at desc);

alter table public.ship_comments enable row level security;

drop policy if exists "ship_comments_read" on public.ship_comments;
create policy "ship_comments_read" on public.ship_comments
  for select using (auth.uid() is not null);

-- Solo perfiles pueden comentar, y el author_user_id debe ser el mismo
-- del auth user (para poder borrar tu comentario mas tarde).
drop policy if exists "ship_comments_insert" on public.ship_comments;
create policy "ship_comments_insert" on public.ship_comments
  for insert with check (
    author_user_id = auth.uid()
    and exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- Borrar: solo el autor.
drop policy if exists "ship_comments_delete" on public.ship_comments;
create policy "ship_comments_delete" on public.ship_comments
  for delete using (author_user_id = auth.uid());

-- Realtime
do $$ begin
  perform 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ship_comments';
  if not found then
    alter publication supabase_realtime add table public.ship_comments;
  end if;
end $$;

alter table public.ship_comments replica identity full;
