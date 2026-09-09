-- =====================================================
-- Contraseñas ligeras por nombre + seccion
-- No usamos Supabase Auth con email/password — cada dispositivo sigue
-- siendo un anon user. La contraseña se guarda hasheada asociada al
-- (name, section) y sirve solo para autorizar reclamar el nombre desde
-- otro dispositivo.
-- =====================================================
create extension if not exists pgcrypto;

create table if not exists public.name_passwords (
  section     text not null check (section in ('A','B')),
  name        text not null,
  hash        text not null,
  updated_at  timestamptz default now(),
  primary key (section, name)
);

alter table public.name_passwords enable row level security;
-- Nadie puede leer/modificar el hash directamente — todo va por RPCs.
drop policy if exists "no_access" on public.name_passwords;
create policy "no_access" on public.name_passwords for all using (false) with check (false);

-- Chequear si un nombre tiene contraseña (sin exponer el hash).
create or replace function public.name_has_password(p_name text, p_section text)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  return exists (
    select 1 from public.name_passwords
     where section = p_section and name = p_name
  );
end;
$$;
grant execute on function public.name_has_password(text, text) to authenticated, anon;

-- Setear/actualizar la contraseña del nombre que YO tengo actualmente
-- reclamado. Solo el dueño actual puede llamar esta RPC.
create or replace function public.set_name_password(p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  me_name text;
  me_section text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_password is null or length(p_password) < 4 then
    raise exception 'password_too_short';
  end if;
  select name, section into me_name, me_section
    from public.profiles where user_id = auth.uid();
  if me_name is null then
    raise exception 'no_profile';
  end if;
  insert into public.name_passwords(section, name, hash, updated_at)
  values (me_section, me_name, crypt(p_password, gen_salt('bf', 10)), now())
  on conflict (section, name)
  do update set hash = excluded.hash, updated_at = now();
end;
$$;
grant execute on function public.set_name_password(text) to authenticated, anon;

-- Quitar la contraseña (solo el dueño actual).
create or replace function public.clear_name_password()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me_name text;
  me_section text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select name, section into me_name, me_section
    from public.profiles where user_id = auth.uid();
  if me_name is null then raise exception 'no_profile'; end if;
  delete from public.name_passwords where section = me_section and name = me_name;
end;
$$;
grant execute on function public.clear_name_password() to authenticated, anon;

-- Reclamar un nombre en otro dispositivo usando la contraseña.
-- Verifica la contraseña, migra toda la data del user_id viejo al nuevo
-- y actualiza el profile. Ignora la ventana "ACTIVE" porque la contraseña
-- prueba que sos el dueño real.
create or replace function public.claim_with_password(p_name text, p_section text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ok boolean;
  v_new_uid uuid := auth.uid();
  v_old_uid uuid;
begin
  if v_new_uid is null then raise exception 'not_authenticated'; end if;
  if p_section not in ('A','B') then raise exception 'invalid_section'; end if;

  -- Verificar contraseña
  select (hash = crypt(p_password, hash)) into v_ok
    from public.name_passwords
   where section = p_section and name = p_name;
  if v_ok is null or v_ok = false then
    raise exception 'bad_password';
  end if;

  -- Owner actual
  select user_id into v_old_uid from public.profiles
   where section = p_section and name = p_name;

  -- Si ya soy yo, refrescar last_seen y salir
  if v_old_uid = v_new_uid then
    update public.profiles set last_seen = now() where user_id = v_new_uid;
    return;
  end if;

  -- Takeover: migrar todo del owner viejo al mio (si hay owner)
  if v_old_uid is not null then
    delete from public.profiles where user_id = v_old_uid;
    -- Chats: transferir creador + mensajes + membresias
    update public.chats set created_by = v_new_uid where created_by = v_old_uid;
    update public.messages set author_user_id = v_new_uid where author_user_id = v_old_uid;
    delete from public.chat_members
      where user_id = v_old_uid
        and chat_id in (select chat_id from public.chat_members where user_id = v_new_uid);
    update public.chat_members set user_id = v_new_uid where user_id = v_old_uid;
    -- Feed
    update public.posts set author_user_id = v_new_uid where author_user_id = v_old_uid;
    update public.post_comments set author_user_id = v_new_uid where author_user_id = v_old_uid;
    delete from public.post_likes
      where user_id = v_old_uid
        and post_id in (select post_id from public.post_likes where user_id = v_new_uid);
    update public.post_likes set user_id = v_new_uid where user_id = v_old_uid;
    update public.stories set author_user_id = v_new_uid where author_user_id = v_old_uid;
    -- Ships
    update public.ships set author_user_id = v_new_uid where author_user_id = v_old_uid;
    delete from public.ship_likes
      where user_id = v_old_uid
        and ship_id in (select ship_id from public.ship_likes where user_id = v_new_uid);
    update public.ship_likes set user_id = v_new_uid where user_id = v_old_uid;
    update public.ship_comments set author_user_id = v_new_uid where author_user_id = v_old_uid;
  end if;

  -- Soltar cualquier otro perfil que yo tuviera
  delete from public.profiles where user_id = v_new_uid and (name <> p_name or section <> p_section);

  -- Crear/refrescar mi perfil
  insert into public.profiles (user_id, name, section, last_seen)
    values (v_new_uid, p_name, p_section, now())
    on conflict (user_id) do update
      set name = excluded.name,
          section = excluded.section,
          last_seen = now();
end;
$$;
grant execute on function public.claim_with_password(text, text, text) to authenticated, anon;
