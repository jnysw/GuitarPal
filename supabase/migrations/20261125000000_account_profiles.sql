begin;

create table public.account_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  handle text unique check (handle ~ '^[a-z0-9][a-z0-9_]{2,19}$'),
  avatar_path text check (
    avatar_path ~ ('^' || user_id::text || '/[0-9a-f-]{36}[.]png$')
  ),
  revision integer not null default 1 check (revision >= 1)
);

alter table public.account_profiles enable row level security;
revoke all on public.account_profiles from public, anon, authenticated;
grant select, insert, update on public.account_profiles to authenticated;

create policy "Read own account profile"
  on public.account_profiles for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Create own account profile"
  on public.account_profiles for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "Update own account profile"
  on public.account_profiles for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', false, 1048576, array['image/png']);

create policy "Read own profile avatars"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Upload own profile avatars"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Remove own profile avatars"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

commit;
