-- =====================================================
-- Panamericana 6to — schema completo
-- Copia y pega esto en Supabase → SQL Editor → Run
-- Idempotente: podés correrlo más de una vez sin romper nada.
-- =====================================================

-- ---------- extensiones ----------
create extension if not exists "pgcrypto";

-- =====================================================
-- 1) PROFILES — un nombre del salón claimado por un uid
-- =====================================================
create table if not exists public.profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  section     text not null check (section in ('A','B')),
  role        text,
  claimed_at  timestamptz default now(),
  unique (name, section)
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles
  for select using (auth.uid() is not null);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (user_id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (user_id = auth.uid());

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
  for delete using (user_id = auth.uid());

-- =====================================================
-- 2) CHISMES — muro anónimo
-- =====================================================
create table if not exists public.chismes (
  id         uuid primary key default gen_random_uuid(),
  text       text not null check (char_length(text) <= 400 and char_length(text) > 0),
  created_at timestamptz default now()
);

alter table public.chismes enable row level security;

drop policy if exists "chismes_read" on public.chismes;
create policy "chismes_read" on public.chismes
  for select using (auth.uid() is not null);

-- Solo usuarios con perfil claimado pueden postear
drop policy if exists "chismes_insert" on public.chismes;
create policy "chismes_insert" on public.chismes
  for insert with check (
    exists (select 1 from public.profiles where user_id = auth.uid())
  );

-- =====================================================
-- 3) CHAT — chats, miembros, mensajes
-- =====================================================
create table if not exists public.chats (
  id          uuid primary key default gen_random_uuid(),
  type        text not null check (type in ('dm','group')),
  name        text,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz default now(),
  dm_key      text unique
);

create table if not exists public.chat_members (
  chat_id       uuid references public.chats(id) on delete cascade,
  user_id       uuid references auth.users(id) on delete cascade,
  joined_at     timestamptz default now(),
  last_read_at  timestamptz default now(),
  primary key (chat_id, user_id)
);

create index if not exists chat_members_user_idx on public.chat_members(user_id);
create index if not exists chat_members_chat_idx on public.chat_members(chat_id);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  chat_id         uuid references public.chats(id) on delete cascade,
  author_user_id  uuid references auth.users(id) on delete set null,
  text            text,
  photo_url       text,
  created_at      timestamptz default now(),
  check (text is not null or photo_url is not null)
);

create index if not exists messages_chat_created_idx on public.messages(chat_id, created_at desc);

-- ---------- helper (evita recursión en RLS) ----------
create or replace function public.is_chat_member(chat_id_input uuid, uid_input uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_members
    where chat_id = chat_id_input and user_id = uid_input
  );
$$;

grant execute on function public.is_chat_member(uuid, uuid) to authenticated, anon;

-- ---------- RLS: chats ----------
alter table public.chats enable row level security;

drop policy if exists "chats_read_member" on public.chats;
create policy "chats_read_member" on public.chats
  for select using (public.is_chat_member(id, auth.uid()));

drop policy if exists "chats_insert" on public.chats;
create policy "chats_insert" on public.chats
  for insert with check (created_by = auth.uid());

-- ---------- RLS: chat_members ----------
alter table public.chat_members enable row level security;

drop policy if exists "chat_members_read" on public.chat_members;
create policy "chat_members_read" on public.chat_members
  for select using (public.is_chat_member(chat_id, auth.uid()));

-- Podés agregarte a un chat si sos el creador del chat, o si te agregás a vos mismo
drop policy if exists "chat_members_insert" on public.chat_members;
create policy "chat_members_insert" on public.chat_members
  for insert with check (
    user_id = auth.uid()
    or exists (select 1 from public.chats c where c.id = chat_id and c.created_by = auth.uid())
  );

-- Solo actualizás tu propia membresía (marcar como leído)
drop policy if exists "chat_members_update_own" on public.chat_members;
create policy "chat_members_update_own" on public.chat_members
  for update using (user_id = auth.uid());

-- ---------- RLS: messages ----------
alter table public.messages enable row level security;

drop policy if exists "messages_read" on public.messages;
create policy "messages_read" on public.messages
  for select using (public.is_chat_member(chat_id, auth.uid()));

drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages
  for insert with check (
    author_user_id = auth.uid()
    and public.is_chat_member(chat_id, auth.uid())
  );

-- =====================================================
-- 4) REALTIME — activar en las tablas relevantes
-- =====================================================
do $$
begin
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages';
  if not found then alter publication supabase_realtime add table public.messages; end if;

  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles';
  if not found then alter publication supabase_realtime add table public.profiles; end if;

  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chismes';
  if not found then alter publication supabase_realtime add table public.chismes; end if;

  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_members';
  if not found then alter publication supabase_realtime add table public.chat_members; end if;

  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chats';
  if not found then alter publication supabase_realtime add table public.chats; end if;
end $$;

-- =====================================================
-- 5) STORAGE — bucket público para fotos del chat
-- =====================================================
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "photos_read" on storage.objects;
create policy "photos_read" on storage.objects
  for select using (bucket_id = 'photos');

drop policy if exists "photos_upload" on storage.objects;
create policy "photos_upload" on storage.objects
  for insert with check (bucket_id = 'photos' and auth.uid() is not null);

drop policy if exists "photos_delete_own" on storage.objects;
create policy "photos_delete_own" on storage.objects
  for delete using (bucket_id = 'photos' and owner = auth.uid());
