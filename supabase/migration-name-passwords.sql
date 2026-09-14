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

-- =====================================================
-- claim_with_password se define ahora (versión NO destructiva, que
-- conserva el perfil y migra follows/vistas) en:
--   migration-account-persistence.sql
-- Se removió de este archivo la versión vieja que borraba el perfil.
-- =====================================================
