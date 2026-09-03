-- =====================================================
-- Panamericana 6to — Presencia + reclamo de nombre (takeover)
-- Copiá y pegá esto en Supabase → SQL Editor → Run.
-- Idempotente: se puede correr más de una vez.
--
-- Problema que resuelve: cada nombre queda "claimado" por un user_id
-- anónimo. Si alguien pierde su sesión (deploy, recarga, otro navegador),
-- obtiene un uid nuevo y su nombre queda atrapado bajo el uid viejo → sale
-- "tomado" aunque sea suyo y nadie lo esté usando.
--
-- Solución: un nombre está "tomado de verdad" solo si tuvo actividad
-- (heartbeat) en los últimos VENTANA segundos. Si está inactivo, cualquiera
-- puede reclamarlo y se migra su historial (chats, mensajes) al nuevo uid.
-- =====================================================

-- 1) Marca de última actividad por perfil
alter table public.profiles
  add column if not exists last_seen timestamptz not null default now();

create index if not exists profiles_last_seen_idx on public.profiles(last_seen);

-- 2) Heartbeat: el dispositivo activo marca su perfil como vivo
create or replace function public.touch_presence()
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles set last_seen = now() where user_id = auth.uid();
$$;

grant execute on function public.touch_presence() to authenticated, anon;

-- 3) ¿Un nombre está activo (tomado ahora mismo en algún dispositivo)?
--    Devuelve: 'free' (libre), 'mine' (tuyo), 'active' (en línea en otro
--    dispositivo), 'idle' (claimado pero sin actividad → reclamable).
create or replace function public.name_status(p_name text, p_section text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles;
  v_window interval := interval '45 seconds';
begin
  select * into v_row from public.profiles where name = p_name and section = p_section;
  if not found then return 'free'; end if;
  if v_row.user_id = v_uid then return 'mine'; end if;
  if v_row.last_seen > now() - v_window then return 'active'; end if;
  return 'idle';
end;
$$;

grant execute on function public.name_status(text, text) to authenticated, anon;

-- 4) Reclamar un nombre. Toma en cuenta la presencia:
--    - si es tuyo → refresca y listo.
--    - si otro lo tiene ACTIVO ahora mismo → error 'ACTIVE'.
--    - si está claimado pero inactivo → takeover: migra chats/mensajes del
--      uid viejo al tuyo y te queda el perfil.
--    - si está libre → lo creás.
create or replace function public.claim_name(p_name text, p_section text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_old public.profiles;
  v_window interval := interval '45 seconds';
  v_result public.profiles;
begin
  if v_uid is null then raise exception 'NO_AUTH'; end if;
  if p_section not in ('A','B') then raise exception 'BAD_SECTION'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'BAD_NAME'; end if;

  select * into v_old from public.profiles where name = p_name and section = p_section;

  if found then
    -- Ya es mío: solo refresco presencia.
    if v_old.user_id = v_uid then
      update public.profiles set last_seen = now()
        where user_id = v_uid returning * into v_result;
      return v_result;
    end if;

    -- Lo tiene otro y está activo ahora mismo → bloquear.
    if v_old.last_seen > now() - v_window then
      raise exception 'ACTIVE';
    end if;

    -- Inactivo → takeover. Primero suelto mi perfil previo (si cambié de nombre).
    delete from public.profiles where user_id = v_uid;

    -- Migrar todas las referencias del uid viejo al mío.
    update public.chats set created_by = v_uid where created_by = v_old.user_id;

    -- chat_members: evitar choque de PK (chat_id, user_id) si ya soy miembro.
    delete from public.chat_members cm
      where cm.user_id = v_old.user_id
        and exists (
          select 1 from public.chat_members x
          where x.chat_id = cm.chat_id and x.user_id = v_uid
        );
    update public.chat_members set user_id = v_uid where user_id = v_old.user_id;

    update public.messages set author_user_id = v_uid where author_user_id = v_old.user_id;

    -- Reasignar el perfil al nuevo uid.
    update public.profiles
      set user_id = v_uid, last_seen = now(), claimed_at = now()
      where name = p_name and section = p_section
      returning * into v_result;
    return v_result;
  else
    -- Nombre libre: suelto mi perfil previo y creo el nuevo.
    delete from public.profiles where user_id = v_uid;
    insert into public.profiles (user_id, name, section, last_seen)
      values (v_uid, p_name, p_section, now())
      returning * into v_result;
    return v_result;
  end if;
end;
$$;

grant execute on function public.claim_name(text, text) to authenticated, anon;
