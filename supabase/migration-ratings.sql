-- =====================================================
-- CALIFICACIONES entre estudiantes (5 estrellas, 2 categorías)
--   categorías: 'atractivo' y 'buena_onda'
--   Cada quien deja UNA calificación por persona y categoría (editable).
--   Anónimo: solo podés leer TUS propias calificaciones vía RLS; los
--   promedios y las listas por usuario se leen por RPC (SECURITY DEFINER)
--   que NO exponen quién calificó.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
create table if not exists public.ratings (
  rater_user_id uuid not null references auth.users(id) on delete cascade,
  rated_user_id uuid not null references auth.users(id) on delete cascade,
  category      text not null check (category in ('atractivo','buena_onda')),
  stars         int  not null check (stars between 1 and 5),
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  primary key (rater_user_id, rated_user_id, category),
  check (rater_user_id <> rated_user_id)
);
create index if not exists ratings_rated_idx on public.ratings(rated_user_id);

alter table public.ratings enable row level security;
-- Solo puedo VER mis propias calificaciones (para saber qué ya puse).
drop policy if exists "ratings_read_own" on public.ratings;
create policy "ratings_read_own" on public.ratings for select using (rater_user_id = auth.uid());
drop policy if exists "ratings_insert_own" on public.ratings;
create policy "ratings_insert_own" on public.ratings for insert with check (
  rater_user_id = auth.uid() and rater_user_id <> rated_user_id
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "ratings_update_own" on public.ratings;
create policy "ratings_update_own" on public.ratings for update using (rater_user_id = auth.uid()) with check (rater_user_id = auth.uid());
drop policy if exists "ratings_delete_own" on public.ratings;
create policy "ratings_delete_own" on public.ratings for delete using (rater_user_id = auth.uid());

-- Promedios por persona y categoría (anónimo: no expone al calificador).
create or replace function public.rating_averages()
returns table (rated_user_id uuid, category text, avg_stars numeric, cnt bigint)
language sql security definer set search_path = public as $$
  select rated_user_id, category, round(avg(stars)::numeric, 2), count(*)
  from public.ratings group by rated_user_id, category;
$$;
grant execute on function public.rating_averages() to authenticated, anon;

-- Lista anónima de estrellas de un usuario (para ver sus calificaciones sin saber quién).
create or replace function public.rating_list(p_user uuid)
returns table (category text, stars int, created_at timestamptz)
language sql security definer set search_path = public as $$
  select category, stars, created_at from public.ratings
  where rated_user_id = p_user order by created_at desc;
$$;
grant execute on function public.rating_list(uuid) to authenticated, anon;
