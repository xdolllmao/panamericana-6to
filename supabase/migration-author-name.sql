-- =====================================================
-- Denormalizar author_name en cada mensaje/post/comment/story
-- Motivo: si un perfil se borra o el auth user se elimina, sus
-- filas quedaban sin manera de resolver el nombre → salian como
-- "Anónimo". Guardar el nombre en la fila lo hace inmutable.
-- =====================================================

-- 1) Columnas nuevas
alter table public.messages       add column if not exists author_name    text;
alter table public.messages       add column if not exists author_section text;

alter table public.posts          add column if not exists author_name    text;
alter table public.posts          add column if not exists author_section text;

alter table public.post_comments  add column if not exists author_name    text;
alter table public.post_comments  add column if not exists author_section text;

alter table public.stories        add column if not exists author_name    text;
alter table public.stories        add column if not exists author_section text;

-- 2) Backfill desde profiles para filas viejas donde aun tenemos el UID
update public.messages m
   set author_name = p.name, author_section = p.section
  from public.profiles p
 where m.author_user_id = p.user_id
   and m.author_name is null;

update public.posts po
   set author_name = pr.name, author_section = pr.section
  from public.profiles pr
 where po.author_user_id = pr.user_id
   and po.author_name is null;

update public.post_comments pc
   set author_name = pr.name, author_section = pr.section
  from public.profiles pr
 where pc.author_user_id = pr.user_id
   and pc.author_name is null;

update public.stories st
   set author_name = pr.name, author_section = pr.section
  from public.profiles pr
 where st.author_user_id = pr.user_id
   and st.author_name is null;

-- 3) Trigger: al insertar cualquier fila nueva, si el cliente no
--    incluyo author_name/author_section, los rellenamos desde el
--    perfil del auth user actual. Asi los inserts viejos que aun no
--    conocen las columnas nuevas tambien quedan cubiertos.
create or replace function public.set_author_name_from_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.author_name is null or new.author_section is null then
    select p.name, p.section
      into new.author_name, new.author_section
      from public.profiles p
     where p.user_id = new.author_user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_messages_author_name on public.messages;
create trigger trg_messages_author_name
  before insert on public.messages
  for each row execute function public.set_author_name_from_profile();

drop trigger if exists trg_posts_author_name on public.posts;
create trigger trg_posts_author_name
  before insert on public.posts
  for each row execute function public.set_author_name_from_profile();

drop trigger if exists trg_post_comments_author_name on public.post_comments;
create trigger trg_post_comments_author_name
  before insert on public.post_comments
  for each row execute function public.set_author_name_from_profile();

drop trigger if exists trg_stories_author_name on public.stories;
create trigger trg_stories_author_name
  before insert on public.stories
  for each row execute function public.set_author_name_from_profile();
