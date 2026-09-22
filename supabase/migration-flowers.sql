-- =====================================================
-- FLORES AMARILLAS (especial): mandar flores a alguien del salón con
-- notita opcional (máx 300) y con nombre o anónimo.
-- Anonimato: se lee por RPC que NO expone al remitente si es anónimo.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
create table if not exists public.flowers (
  id                uuid primary key default gen_random_uuid(),
  sender_user_id    uuid references auth.users(id) on delete set null,
  recipient_name    text not null,
  recipient_section text not null check (recipient_section in ('A','B')),
  note              text check (note is null or char_length(note) <= 300),
  anonymous         boolean not null default false,
  sender_name       text,
  created_at        timestamptz default now(),
  seen_at           timestamptz
);
create index if not exists flowers_recipient_idx on public.flowers(recipient_section, recipient_name);

alter table public.flowers enable row level security;
-- Enviar: solo con perfil, y me registro como remitente.
drop policy if exists "flowers_insert" on public.flowers;
create policy "flowers_insert" on public.flowers for insert with check (
  sender_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
-- (sin select/update directo → lectura y marcar-visto van por RPC anónimo)

-- Flores que me enviaron (según mi perfil). Oculta al remitente si es anónimo.
create or replace function public.my_flowers()
returns table (id uuid, note text, sender text, anonymous boolean, created_at timestamptz, seen_at timestamptz)
language sql security definer set search_path = public as $$
  select f.id, f.note,
         case when f.anonymous then null else f.sender_name end as sender,
         f.anonymous, f.created_at, f.seen_at
  from public.flowers f
  join public.profiles p
    on p.user_id = auth.uid()
   and lower(p.name) = lower(f.recipient_name)
   and p.section = f.recipient_section
  order by f.created_at desc;
$$;
grant execute on function public.my_flowers() to authenticated, anon;

-- Marcar como vistas mis flores.
create or replace function public.mark_flowers_seen()
returns void language sql security definer set search_path = public as $$
  update public.flowers f set seen_at = now()
  from public.profiles p
  where p.user_id = auth.uid()
    and lower(p.name) = lower(f.recipient_name)
    and p.section = f.recipient_section
    and f.seen_at is null;
$$;
grant execute on function public.mark_flowers_seen() to authenticated, anon;
