-- =====================================================
-- FIX: al reclamar/migrar una cuenta (claim_name / claim_with_password)
-- se perdía la foto de perfil (avatar_url), bio, redes y rol porque el
-- perfil viejo se BORRABA y se creaba uno nuevo vacío.
-- Solución: REASIGNAR la fila del perfil al nuevo uid (conserva todo).
-- =====================================================

-- ---------- claim_name (takeover preservando el perfil) ----------
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
    if v_old.user_id = v_uid then
      update public.profiles set last_seen = now() where user_id = v_uid returning * into v_result;
      return v_result;
    end if;
    if v_old.last_seen > now() - v_window then
      raise exception 'ACTIVE';
    end if;

    -- Takeover: soltar mi perfil previo (si cambié de nombre) y migrar refs.
    delete from public.profiles where user_id = v_uid;
    perform public._migrate_user_refs(v_old.user_id, v_uid);

    -- REASIGNAR el perfil existente (conserva avatar_url, bio, redes, rol).
    update public.profiles
      set user_id = v_uid, last_seen = now(), claimed_at = now()
      where name = p_name and section = p_section
      returning * into v_result;
    return v_result;
  else
    delete from public.profiles where user_id = v_uid;
    insert into public.profiles (user_id, name, section, last_seen)
      values (v_uid, p_name, p_section, now())
      returning * into v_result;
    return v_result;
  end if;
end;
$$;
grant execute on function public.claim_name(text, text) to authenticated, anon;

-- ---------- helper: migrar todas las referencias de un uid viejo al nuevo ----------
create or replace function public._migrate_user_refs(v_old uuid, v_new uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if v_old is null or v_new is null or v_old = v_new then return; end if;

  update public.chats set created_by = v_new where created_by = v_old;

  delete from public.chat_members cm
    where cm.user_id = v_old
      and exists (select 1 from public.chat_members x where x.chat_id = cm.chat_id and x.user_id = v_new);
  update public.chat_members set user_id = v_new where user_id = v_old;

  update public.messages set author_user_id = v_new where author_user_id = v_old;

  -- feed
  update public.posts set author_user_id = v_new where author_user_id = v_old;
  update public.post_comments set author_user_id = v_new where author_user_id = v_old;
  delete from public.post_likes pl
    where pl.user_id = v_old
      and exists (select 1 from public.post_likes x where x.post_id = pl.post_id and x.user_id = v_new);
  update public.post_likes set user_id = v_new where user_id = v_old;
  update public.stories set author_user_id = v_new where author_user_id = v_old;

  -- ships
  update public.ships set author_user_id = v_new where author_user_id = v_old;
  delete from public.ship_likes sl
    where sl.user_id = v_old
      and exists (select 1 from public.ship_likes x where x.ship_id = sl.ship_id and x.user_id = v_new);
  update public.ship_likes set user_id = v_new where user_id = v_old;
  update public.ship_comments set author_user_id = v_new where author_user_id = v_old;

  -- musica (si existen las tablas)
  begin
    update public.songs set author_user_id = v_new where author_user_id = v_old;
    delete from public.song_likes sl
      where sl.user_id = v_old
        and exists (select 1 from public.song_likes x where x.song_id = sl.song_id and x.user_id = v_new);
    update public.song_likes set user_id = v_new where user_id = v_old;
  exception when undefined_table then null;
  end;
end;
$$;
grant execute on function public._migrate_user_refs(uuid, uuid) to authenticated, anon;

-- ---------- claim_with_password (takeover con contraseña, preservando el perfil) ----------
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

  select (hash = crypt(p_password, hash)) into v_ok
    from public.name_passwords where section = p_section and name = p_name;
  if v_ok is null or v_ok = false then raise exception 'bad_password'; end if;

  select user_id into v_old_uid from public.profiles where section = p_section and name = p_name;

  if v_old_uid = v_new_uid then
    update public.profiles set last_seen = now() where user_id = v_new_uid;
    return;
  end if;

  if v_old_uid is not null then
    -- soltar mi perfil previo y migrar refs del viejo al nuevo
    delete from public.profiles where user_id = v_new_uid;
    perform public._migrate_user_refs(v_old_uid, v_new_uid);
    -- REASIGNAR el perfil (conserva avatar_url, bio, redes, rol)
    update public.profiles set user_id = v_new_uid, last_seen = now()
      where section = p_section and name = p_name;
  else
    delete from public.profiles where user_id = v_new_uid and (name <> p_name or section <> p_section);
    insert into public.profiles (user_id, name, section, last_seen)
      values (v_new_uid, p_name, p_section, now())
      on conflict (user_id) do update set name = excluded.name, section = excluded.section, last_seen = now();
  end if;
end;
$$;
grant execute on function public.claim_with_password(text, text, text) to authenticated, anon;
