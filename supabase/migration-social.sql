-- =====================================================
-- Sistema social completo: perfiles ampliados, follows,
-- posts (reels, photos, opinions), likes, comments,
-- profile views, storage.
-- Correr en Supabase → SQL Editor → Run. Idempotente.
-- =====================================================

-- Extender profiles con bio, avatar, socials
alter table public.profiles
  add column if not exists bio        text,
  add column if not exists avatar_url text,
  add column if not exists instagram  text,
  add column if not exists tiktok     text,
  add column if not exists twitter    text;

-- =====================================================
-- FOLLOWS
-- =====================================================
create table if not exists public.follows (
  follower_id uuid references auth.users(id) on delete cascade,
  followed_id uuid references auth.users(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index if not exists follows_followed_idx on public.follows(followed_id);
alter table public.follows enable row level security;
drop policy if exists "follows_read" on public.follows;
create policy "follows_read" on public.follows for select using (auth.uid() is not null);
drop policy if exists "follows_insert_own" on public.follows;
create policy "follows_insert_own" on public.follows for insert with check (follower_id = auth.uid());
drop policy if exists "follows_delete_own" on public.follows;
create policy "follows_delete_own" on public.follows for delete using (follower_id = auth.uid());

-- =====================================================
-- POSTS (reels, photos, opinions)
-- =====================================================
create table if not exists public.posts (
  id             uuid primary key default gen_random_uuid(),
  author_user_id uuid references auth.users(id) on delete cascade,
  type           text not null check (type in ('reel','photo','opinion')),
  description    text,
  media_url      text,
  media_type     text,
  created_at     timestamptz default now()
);
create index if not exists posts_author_idx on public.posts(author_user_id);
create index if not exists posts_created_idx on public.posts(created_at desc);
alter table public.posts enable row level security;
drop policy if exists "posts_read" on public.posts;
create policy "posts_read" on public.posts for select using (auth.uid() is not null);
drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts for insert with check (
  author_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts for delete using (author_user_id = auth.uid());

-- =====================================================
-- LIKES
-- =====================================================
create table if not exists public.post_likes (
  post_id     uuid references public.posts(id) on delete cascade,
  user_id     uuid references auth.users(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (post_id, user_id)
);
create index if not exists post_likes_user_idx on public.post_likes(user_id);
alter table public.post_likes enable row level security;
drop policy if exists "likes_read" on public.post_likes;
create policy "likes_read" on public.post_likes for select using (auth.uid() is not null);
drop policy if exists "likes_insert_own" on public.post_likes;
create policy "likes_insert_own" on public.post_likes for insert with check (user_id = auth.uid());
drop policy if exists "likes_delete_own" on public.post_likes;
create policy "likes_delete_own" on public.post_likes for delete using (user_id = auth.uid());

-- =====================================================
-- COMMENTS
-- =====================================================
create table if not exists public.post_comments (
  id             uuid primary key default gen_random_uuid(),
  post_id        uuid references public.posts(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  text           text not null check (char_length(text) between 1 and 500),
  created_at     timestamptz default now()
);
create index if not exists post_comments_post_idx on public.post_comments(post_id, created_at);
alter table public.post_comments enable row level security;
drop policy if exists "comments_read" on public.post_comments;
create policy "comments_read" on public.post_comments for select using (auth.uid() is not null);
drop policy if exists "comments_insert_own" on public.post_comments;
create policy "comments_insert_own" on public.post_comments for insert with check (
  author_user_id = auth.uid()
  and exists (select 1 from public.profiles where user_id = auth.uid())
);
drop policy if exists "comments_delete_own" on public.post_comments;
create policy "comments_delete_own" on public.post_comments for delete using (author_user_id = auth.uid());

-- =====================================================
-- PROFILE VIEWS
-- =====================================================
create table if not exists public.profile_views (
  viewer_id      uuid references auth.users(id) on delete cascade,
  viewed_user_id uuid references auth.users(id) on delete cascade,
  viewed_at      timestamptz default now(),
  primary key (viewer_id, viewed_user_id),
  check (viewer_id <> viewed_user_id)
);
create index if not exists profile_views_viewed_idx on public.profile_views(viewed_user_id, viewed_at desc);
alter table public.profile_views enable row level security;
-- El dueño del perfil ve quién lo vio; el viewer ve su propio historial
drop policy if exists "views_read_owner_or_self" on public.profile_views;
create policy "views_read_owner_or_self" on public.profile_views
  for select using (viewed_user_id = auth.uid() or viewer_id = auth.uid());
drop policy if exists "views_insert_own" on public.profile_views;
create policy "views_insert_own" on public.profile_views
  for insert with check (viewer_id = auth.uid() and viewer_id <> viewed_user_id);
drop policy if exists "views_update_own" on public.profile_views;
create policy "views_update_own" on public.profile_views for update using (viewer_id = auth.uid());

-- =====================================================
-- STORAGE: avatars + posts
-- =====================================================
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('posts', 'posts', true) on conflict (id) do nothing;

drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read" on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists "avatars_upload" on storage.objects;
create policy "avatars_upload" on storage.objects for insert with check (bucket_id = 'avatars' and auth.uid() is not null);
drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects for update using (bucket_id = 'avatars' and owner = auth.uid());
drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects for delete using (bucket_id = 'avatars' and owner = auth.uid());

drop policy if exists "posts_media_read" on storage.objects;
create policy "posts_media_read" on storage.objects for select using (bucket_id = 'posts');
drop policy if exists "posts_media_upload" on storage.objects;
create policy "posts_media_upload" on storage.objects for insert with check (bucket_id = 'posts' and auth.uid() is not null);
drop policy if exists "posts_media_delete_own" on storage.objects;
create policy "posts_media_delete_own" on storage.objects for delete using (bucket_id = 'posts' and owner = auth.uid());

-- =====================================================
-- REALTIME
-- =====================================================
do $$
begin
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'posts';
  if not found then alter publication supabase_realtime add table public.posts; end if;
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_likes';
  if not found then alter publication supabase_realtime add table public.post_likes; end if;
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_comments';
  if not found then alter publication supabase_realtime add table public.post_comments; end if;
  perform 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'follows';
  if not found then alter publication supabase_realtime add table public.follows; end if;
end $$;
