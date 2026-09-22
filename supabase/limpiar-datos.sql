-- =====================================================
-- Limpieza de datos en la base (opcional). Corré primero los SELECT para
-- ver cuánto vas a borrar, y después descomentá los DELETE que quieras.
-- OJO: los DELETE son irreversibles. Esto NO borra los archivos de Storage
-- (fotos/videos/audios); para eso usá scripts/limpiar-storage.mjs.
-- =====================================================

-- 1) Ver el peso de cada bucket de Storage (lo que más pesa):
select bucket_id,
       count(*) as archivos,
       pg_size_pretty(coalesce(sum((metadata->>'size')::bigint),0)) as peso
from storage.objects
group by bucket_id
order by sum((metadata->>'size')::bigint) desc nulls last;

-- 2) Cuántos mensajes viejos hay (más de 30 días):
select count(*) from public.messages where created_at < now() - interval '30 days';

-- 3) Cuántas historias viejas (ya vencidas, más de 1 día):
select count(*) from public.stories where created_at < now() - interval '1 day';

-- ---------- BORRADOS (descomentá el que quieras) ----------

-- Borrar mensajes de más de 30 días (quita texto y referencias a fotos del chat):
-- delete from public.messages where created_at < now() - interval '30 days';

-- Borrar SOLO los mensajes que eran fotos, de más de 7 días:
-- delete from public.messages where photo_url is not null and created_at < now() - interval '7 days';

-- Borrar historias vencidas (más de 1 día):
-- delete from public.stories where created_at < now() - interval '1 day';

-- Recuperar espacio en disco de la base después de borrar mucho:
-- vacuum (analyze) public.messages;
-- vacuum (analyze) public.stories;
