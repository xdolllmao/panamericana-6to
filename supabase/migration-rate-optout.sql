-- =====================================================
-- Opt-out de las calificaciones: si rate_opt_out = true, la persona NO
-- aparece en el feed de calificar ni en el ranking.
-- Idempotente. Correr en Supabase → SQL Editor.
-- =====================================================
alter table public.profiles add column if not exists rate_opt_out boolean not null default false;
