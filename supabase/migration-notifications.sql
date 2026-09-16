-- =====================================================
-- NOTIFICACIONES (bandeja de entrada)
--   Se generan por TRIGGERS (SECURITY DEFINER) cuando:
--     - te mandan un mensaje (DM o grupo)
--     - le dan like o comentan tu publicación del feed
--     - le dan like o comentan tu ship            (anónimo → sin actor)
--     - le dan like/dislike o comentan tu protesta (anónimo → sin actor)
--   Anonimato: en ships/protestas actor_user_id se guarda NULL, así el
--   destinatario NUNCA puede saber quién fue.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
create table if not exists public.notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade, -- destinatario
  type          text not null,
  actor_user_id uuid references auth.users(id) on delete set null,          -- null = anónimo
  entity_id     uuid,          -- chat_id / post_id / ship_id / protest_id
  snippet       text,
  created_at    timestamptz default now(),
  read_at       timestamptz
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);
alter table public.notifications enable row level security;
-- Solo el destinatario lee/edita/borra las suyas. Insertan únicamente los triggers.
drop policy if exists "notifications_read_own" on public.notifications;
create policy "notifications_read_own" on public.notifications for select using (user_id = auth.uid());
drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own" on public.notifications for delete using (user_id = auth.uid());

-- ---- mensajes (DM / grupo): notifica a los demás miembros ----
create or replace function public.notify_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, type, actor_user_id, entity_id, snippet)
  select cm.user_id, 'message', new.author_user_id, new.chat_id, left(coalesce(new.text,''), 80)
  from public.chat_members cm
  where cm.chat_id = new.chat_id and cm.user_id <> new.author_user_id;
  return new;
end; $$;
drop trigger if exists trg_notify_message on public.messages;
create trigger trg_notify_message after insert on public.messages
  for each row execute function public.notify_message();

-- ---- feed: like en tu post (no anónimo) ----
create or replace function public.notify_post_like() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.posts where id = new.post_id;
  if v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id)
    values (v_owner, 'post_like', new.user_id, new.post_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_post_like on public.post_likes;
create trigger trg_notify_post_like after insert on public.post_likes
  for each row execute function public.notify_post_like();

-- ---- feed: comentario en tu post ----
create or replace function public.notify_post_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.posts where id = new.post_id;
  if v_owner is not null and v_owner <> new.author_user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id, snippet)
    values (v_owner, 'post_comment', new.author_user_id, new.post_id, left(coalesce(new.text,''), 80));
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_post_comment on public.post_comments;
create trigger trg_notify_post_comment after insert on public.post_comments
  for each row execute function public.notify_post_comment();

-- ---- ship: like (ANÓNIMO, actor null) ----
create or replace function public.notify_ship_like() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.ships where id = new.ship_id;
  if v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id)
    values (v_owner, 'ship_like', null, new.ship_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_ship_like on public.ship_likes;
create trigger trg_notify_ship_like after insert on public.ship_likes
  for each row execute function public.notify_ship_like();

-- ---- ship: comentario (ANÓNIMO) ----
create or replace function public.notify_ship_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.ships where id = new.ship_id;
  if v_owner is not null and v_owner <> new.author_user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id, snippet)
    values (v_owner, 'ship_comment', null, new.ship_id, left(coalesce(new.text,''), 80));
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_ship_comment on public.ship_comments;
create trigger trg_notify_ship_comment after insert on public.ship_comments
  for each row execute function public.notify_ship_comment();

-- ---- protesta: like / dislike / comentario (ANÓNIMO) ----
create or replace function public.notify_protest_like() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.protests where id = new.protest_id;
  if v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id)
    values (v_owner, 'protest_like', null, new.protest_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_protest_like on public.protest_likes;
create trigger trg_notify_protest_like after insert on public.protest_likes
  for each row execute function public.notify_protest_like();

create or replace function public.notify_protest_dislike() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.protests where id = new.protest_id;
  if v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id)
    values (v_owner, 'protest_dislike', null, new.protest_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_protest_dislike on public.protest_dislikes;
create trigger trg_notify_protest_dislike after insert on public.protest_dislikes
  for each row execute function public.notify_protest_dislike();

create or replace function public.notify_protest_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select author_user_id into v_owner from public.protests where id = new.protest_id;
  if v_owner is not null and v_owner <> new.author_user_id then
    insert into public.notifications(user_id, type, actor_user_id, entity_id, snippet)
    values (v_owner, 'protest_comment', null, new.protest_id, left(coalesce(new.text,''), 80));
  end if;
  return new;
end; $$;
drop trigger if exists trg_notify_protest_comment on public.protest_comments;
create trigger trg_notify_protest_comment after insert on public.protest_comments
  for each row execute function public.notify_protest_comment();

-- ---- realtime ----
do $$
begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications';
  if not found then alter publication supabase_realtime add table public.notifications; end if;
end $$;
alter table public.notifications replica identity full;
