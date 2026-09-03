-- =====================================================
-- Liberar el nombre "Valentina"
-- Supabase → SQL Editor → Run. (Corre con service role, ignora RLS.)
--
-- Borra el perfil que tenga ese nombre en cualquier sección, junto con
-- su historial (chats propios, membresías y mensajes) para que el nombre
-- quede 100% libre y reclamable por cualquiera.
-- =====================================================

do $$
declare
  v_uid uuid;
begin
  select user_id into v_uid from public.profiles where lower(name) = 'valentina' limit 1;

  if v_uid is null then
    raise notice 'No hay ningún perfil llamado "Valentina" — ya está libre.';
    return;
  end if;

  delete from public.messages       where author_user_id = v_uid;
  delete from public.chat_members   where user_id        = v_uid;
  delete from public.chats          where created_by     = v_uid;
  delete from public.profiles       where user_id        = v_uid;

  raise notice 'Nombre "Valentina" liberado (uid % eliminado).', v_uid;
end $$;
