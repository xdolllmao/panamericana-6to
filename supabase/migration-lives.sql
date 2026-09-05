-- =====================================================
-- LIVES + LIVE_MESSAGES (comentarios flotantes + regalos)
-- Correr en Supabase → SQL Editor. Idempotente.
-- =====================================================

create table if not exists public.lives (
  id                  uuid primary key default gen_random_uuid(),
  broadcaster_user_id uuid references auth.users(id) on delete cascade,
  title               text,
  room_name           text unique not null,
  started_at          timestamptz default now(),
  ended_at            timestamptz
);
create index if not exists lives_active_idx on public.lives(started_at desc) where ended_at is null;

alter table public.lives enable row level security;

drop policy if exists "lives_read" on public.lives;
create policy "lives_read" on public.lives for select using (auth.uid() is not null);

drop policy if exists "lives_insert_own" on public.lives;
create policy "lives_insert_own" on public.lives for insert with check (
  broadcaster_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);

drop policy if exists "lives_update_own" on public.lives;
create policy "lives_update_own" on public.lives for update using (broadcaster_user_id = auth.uid());

drop policy if exists "lives_delete_own" on public.lives;
create policy "lives_delete_own" on public.lives for delete using (broadcaster_user_id = auth.uid());

create table if not exists public.live_messages (
  id             uuid primary key default gen_random_uuid(),
  live_id        uuid references public.lives(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  kind           text not null check (kind in ('text','gift','like','join')),
  text           text,
  gift           text,
  created_at     timestamptz default now()
);
create index if not exists live_messages_live_idx on public.live_messages(live_id, created_at);

alter table public.live_messages enable row level security;

drop policy if exists "live_messages_read" on public.live_messages;
create policy "live_messages_read" on public.live_messages for select using (auth.uid() is not null);

drop policy if exists "live_messages_insert_own" on public.live_messages;
create policy "live_messages_insert_own" on public.live_messages for insert with check (
  author_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);

do $$ begin
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lives';
  if not found then alter publication supabase_realtime add table public.lives; end if;
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_messages';
  if not found then alter publication supabase_realtime add table public.live_messages; end if;
end $$;
