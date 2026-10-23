-- ════════════════════════════════════════════════════════════════════
--  Instagram replica: database schema, security rules and storage.
--
--  Run this ONCE in the Supabase dashboard:
--    SQL Editor → New query → paste this whole file → Run.
--  It is safe to run again: everything uses "if not exists" / "or replace".
--
--  Your project already had profiles, follows, posts, likes, comments,
--  notes and messages. Those tables are kept (with their data); this script
--  only adds the columns and tables the app needs on top of them.
-- ════════════════════════════════════════════════════════════════════

-- ───────────── Profiles ─────────────
create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  username       text not null unique,
  full_name      text not null default '',
  bio            text not null default '',
  avatar_url     text,
  is_private     boolean not null default false,
  last_active_at timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9._]{3,30}$')
);

alter table public.profiles add column if not exists full_name text not null default '';
alter table public.profiles add column if not exists bio text not null default '';
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists is_private boolean not null default false;
alter table public.profiles add column if not exists last_active_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- Builds a unique username from an email: "Juan.Dela-Cruz@x.com" -> "juan.delacruz"
create or replace function public.make_username(source text)
returns text
language plpgsql
as $$
declare
  base text;
  candidate text;
begin
  base := lower(regexp_replace(split_part(coalesce(source, ''), '@', 1), '[^a-zA-Z0-9._]', '', 'g'));
  if length(base) < 3 then
    base := 'user' || base;
  end if;
  base := left(base, 24);
  candidate := base;
  while exists (select 1 from public.profiles where username = candidate) loop
    candidate := base || floor(random() * 9000 + 1000)::int::text;
  end loop;
  return candidate;
end;
$$;

-- Every new account gets a profile automatically.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    public.make_username(coalesce(new.email, new.id::text)),
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Accounts that existed before this script also get a profile.
insert into public.profiles (id, username)
select u.id, public.make_username(coalesce(u.email, u.id::text))
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- Older profiles without a username get one from their email.
update public.profiles p
set username = public.make_username(coalesce(u.email, u.id::text))
from auth.users u
where u.id = p.id and (p.username is null or p.username = '');

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ───────────── Follows (Add friend / Follow) ─────────────
create table if not exists public.follows (
  follower_id  uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id);
-- One row per pair (the app relies on this for follow / unfollow).
create unique index if not exists follows_pair_idx
  on public.follows (follower_id, following_id);

-- ───────────── Posts ─────────────
create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  caption    text not null default '',
  location   text not null default '',
  image_url  text,
  image_urls text[],
  created_at timestamptz not null default now()
);
-- Existing posts table stores one photo in image_url; multi-photo posts
-- use image_urls (image_url keeps the first photo).
alter table public.posts add column if not exists image_url text;
alter table public.posts add column if not exists image_urls text[];
alter table public.posts add column if not exists location text not null default '';
update public.posts set image_urls = array[image_url]
where image_urls is null and image_url is not null;
create index if not exists posts_user_idx on public.posts (user_id, created_at desc);

create table if not exists public.likes (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create unique index if not exists likes_pair_idx
  on public.likes (post_id, user_id);

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (length(body) between 1 and 2200),
  created_at timestamptz not null default now()
);
create index if not exists comments_post_idx on public.comments (post_id, created_at);

create table if not exists public.saved_posts (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- ───────────── Stories (disappear after 24 hours) ─────────────
create table if not exists public.stories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  media_url   text not null,
  media_type  text not null default 'image' check (media_type in ('image', 'video')),
  overlays    jsonb not null default '[]'::jsonb,
  duration_ms integer not null default 5000,
  close_friends boolean not null default false,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '24 hours'
);
create index if not exists stories_user_idx on public.stories (user_id, created_at);

create table if not exists public.story_views (
  story_id  uuid not null references public.stories (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create table if not exists public.story_likes (
  story_id   uuid not null references public.stories (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

-- ───────────── Notes / My Day (one per user, 24 hours) ─────────────
create table if not exists public.notes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references public.profiles (id) on delete cascade,
  content    text not null check (length(content) between 1 and 60),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
alter table public.notes add column if not exists expires_at timestamptz
  not null default now() + interval '24 hours';

create table if not exists public.note_likes (
  note_id    uuid not null references public.notes (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (note_id, user_id)
);

-- ───────────── Direct messages ─────────────
create table if not exists public.messages (
  id                uuid primary key default gen_random_uuid(),
  sender_id         uuid not null references public.profiles (id) on delete cascade,
  receiver_id       uuid not null references public.profiles (id) on delete cascade,
  body              text not null default '',
  media_url         text,
  -- "story_reply", "note_reply" or "post_share": shown above the message.
  context_type      text,
  context_text      text,
  context_media_url text,
  created_at        timestamptz not null default now(),
  read_at           timestamptz,
  constraint not_empty check (length(body) > 0 or media_url is not null)
);
alter table public.messages add column if not exists media_url text;
alter table public.messages add column if not exists context_type text;
alter table public.messages add column if not exists context_text text;
alter table public.messages add column if not exists context_media_url text;
alter table public.messages add column if not exists read_at timestamptz;

create index if not exists messages_pair_idx
  on public.messages (sender_id, receiver_id, created_at desc);
create index if not exists messages_receiver_idx
  on public.messages (receiver_id, created_at desc);

-- ════════════════════ Row Level Security ════════════════════
alter table public.profiles      enable row level security;
alter table public.follows       enable row level security;
alter table public.posts         enable row level security;
alter table public.likes    enable row level security;
alter table public.comments enable row level security;
alter table public.saved_posts   enable row level security;
alter table public.stories       enable row level security;
alter table public.story_views   enable row level security;
alter table public.story_likes   enable row level security;
alter table public.notes         enable row level security;
alter table public.note_likes    enable row level security;
alter table public.messages      enable row level security;

-- Profiles: anyone signed in can read; you edit only yours.
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles
  for select to authenticated using (true);
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
  for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Follows
drop policy if exists "follows read" on public.follows;
create policy "follows read" on public.follows
  for select to authenticated using (true);
drop policy if exists "follows insert own" on public.follows;
create policy "follows insert own" on public.follows
  for insert to authenticated with check (follower_id = auth.uid());
drop policy if exists "follows delete own" on public.follows;
create policy "follows delete own" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

-- Posts
drop policy if exists "posts read" on public.posts;
create policy "posts read" on public.posts
  for select to authenticated using (true);
drop policy if exists "posts insert own" on public.posts;
create policy "posts insert own" on public.posts
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "posts update own" on public.posts;
create policy "posts update own" on public.posts
  for update to authenticated using (user_id = auth.uid());
drop policy if exists "posts delete own" on public.posts;
create policy "posts delete own" on public.posts
  for delete to authenticated using (user_id = auth.uid());

-- Likes
drop policy if exists "post likes read" on public.likes;
create policy "post likes read" on public.likes
  for select to authenticated using (true);
drop policy if exists "post likes insert own" on public.likes;
create policy "post likes insert own" on public.likes
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "post likes delete own" on public.likes;
create policy "post likes delete own" on public.likes
  for delete to authenticated using (user_id = auth.uid());

-- Comments
drop policy if exists "comments read" on public.comments;
create policy "comments read" on public.comments
  for select to authenticated using (true);
drop policy if exists "comments insert own" on public.comments;
create policy "comments insert own" on public.comments
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "comments delete own" on public.comments;
create policy "comments delete own" on public.comments
  for delete to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid())
  );

-- Saved posts are private to you.
drop policy if exists "saved own" on public.saved_posts;
create policy "saved own" on public.saved_posts
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Stories: everyone sees active ones; you also see your own expired ones (archive).
drop policy if exists "stories read" on public.stories;
create policy "stories read" on public.stories
  for select to authenticated using (expires_at > now() or user_id = auth.uid());
drop policy if exists "stories insert own" on public.stories;
create policy "stories insert own" on public.stories
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "stories delete own" on public.stories;
create policy "stories delete own" on public.stories
  for delete to authenticated using (user_id = auth.uid());

-- Story views: you record your own views; the story owner sees who viewed.
drop policy if exists "story views read" on public.story_views;
create policy "story views read" on public.story_views
  for select to authenticated using (
    viewer_id = auth.uid()
    or exists (select 1 from public.stories s where s.id = story_id and s.user_id = auth.uid())
  );
drop policy if exists "story views insert own" on public.story_views;
create policy "story views insert own" on public.story_views
  for insert to authenticated with check (viewer_id = auth.uid());

drop policy if exists "story likes read" on public.story_likes;
create policy "story likes read" on public.story_likes
  for select to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from public.stories s where s.id = story_id and s.user_id = auth.uid())
  );
drop policy if exists "story likes insert own" on public.story_likes;
create policy "story likes insert own" on public.story_likes
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "story likes delete own" on public.story_likes;
create policy "story likes delete own" on public.story_likes
  for delete to authenticated using (user_id = auth.uid());

-- Notes
drop policy if exists "notes read" on public.notes;
create policy "notes read" on public.notes
  for select to authenticated using (true);
drop policy if exists "notes write own" on public.notes;
create policy "notes write own" on public.notes
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "note likes read" on public.note_likes;
create policy "note likes read" on public.note_likes
  for select to authenticated using (true);
drop policy if exists "note likes write own" on public.note_likes;
create policy "note likes write own" on public.note_likes
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Messages: only the two people in the conversation can see them.
drop policy if exists "messages read own" on public.messages;
create policy "messages read own" on public.messages
  for select to authenticated using (auth.uid() in (sender_id, receiver_id));
drop policy if exists "messages send" on public.messages;
create policy "messages send" on public.messages
  for insert to authenticated with check (sender_id = auth.uid());
drop policy if exists "messages mark read" on public.messages;
create policy "messages mark read" on public.messages
  for update to authenticated using (receiver_id = auth.uid());
drop policy if exists "messages unsend" on public.messages;
create policy "messages unsend" on public.messages
  for delete to authenticated using (sender_id = auth.uid());

-- ════════════════════ Realtime ════════════════════
-- Live updates for chat, so new messages appear without refreshing.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
alter table public.messages replica identity full;

-- ════════════════════ Storage (photos and videos) ════════════════════
-- Files are stored under "<user id>/<file name>", and only you can upload
-- or delete inside your own folder.
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('posts',   'posts',   true),
  ('stories', 'stories', true),
  ('chat',    'chat',    true)
on conflict (id) do nothing;
update storage.buckets set public = true
where id in ('avatars', 'posts', 'stories', 'chat');

drop policy if exists "media read" on storage.objects;
create policy "media read" on storage.objects
  for select using (bucket_id in ('avatars', 'posts', 'stories', 'chat'));

drop policy if exists "media upload own folder" on storage.objects;
create policy "media upload own folder" on storage.objects
  for insert to authenticated with check (
    bucket_id in ('avatars', 'posts', 'stories', 'chat')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "media update own folder" on storage.objects;
create policy "media update own folder" on storage.objects
  for update to authenticated using (
    bucket_id in ('avatars', 'posts', 'stories', 'chat')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "media delete own folder" on storage.objects;
create policy "media delete own folder" on storage.objects
  for delete to authenticated using (
    bucket_id in ('avatars', 'posts', 'stories', 'chat')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
