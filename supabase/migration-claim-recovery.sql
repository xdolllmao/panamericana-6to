-- =====================================================
-- Fix: claim_name debe migrar chats/mensajes/membresías
-- cuando hacés takeover de un nombre desde otro dispositivo.
-- Correr en Supabase → SQL Editor → Run.
-- Idempotente (create or replace).
-- =====================================================

create or replace function public.claim_name(p_name text, p_section text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_old_uid uuid;
  v_old_last_seen timestamptz;
  v_active_window interval := interval '45 seconds';
begin
  if v_uid is null then raise exception 'must be signed in'; end if;
  if p_section not in ('A','B') then raise exception 'invalid section'; end if;

  select user_id, last_seen into v_old_uid, v_old_last_seen
    from public.profiles where name = p_name and section = p_section;

  -- Ya es mío → refresco presencia y salgo
  if v_old_uid = v_uid then
    update public.profiles set last_seen = now() where user_id = v_uid;
    return;
  end if;

  -- Está tomado por otro
  if v_old_uid is not null then
    -- Si el otro dispositivo está activo (heartbeat < 45s), no dejo tomar
    if v_old_last_seen is not null and v_old_last_seen > now() - v_active_window then
      raise exception 'ACTIVE';
    end if;

    -- Takeover: migrar TODO del user viejo al mío
    delete from public.profiles where user_id = v_old_uid;
    update public.chats set created_by = v_uid where created_by = v_old_uid;
    update public.messages set author_user_id = v_uid where author_user_id = v_old_uid;
    -- Membresías: si ya estoy en el mismo chat, borro la del viejo (evita conflicto de PK); si no, transfiero
    delete from public.chat_members
      where user_id = v_old_uid
        and chat_id in (select chat_id from public.chat_members where user_id = v_uid);
    update public.chat_members set user_id = v_uid where user_id = v_old_uid;
  end if;

  -- Si yo tenía otro perfil (cambio de nombre), lo suelto
  delete from public.profiles where user_id = v_uid and (name != p_name or section != p_section);

  -- Crear o refrescar mi perfil
  insert into public.profiles (user_id, name, section, last_seen)
    values (v_uid, p_name, p_section, now())
    on conflict (user_id) do update
      set name = excluded.name,
          section = excluded.section,
          last_seen = now();
end;
$$;

grant execute on function public.claim_name(text, text) to authenticated, anon;
