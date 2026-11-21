-- Ejecutar completo en Supabase → SQL Editor
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  dept text not null default 'Artes Visuales',
  created_at timestamptz not null default now()
);
create table public.artworks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  category text,
  technique text,
  year text,
  dimensions text,
  tags text[] not null default '{}',
  image_url text not null,
  created_at timestamptz not null default now()
);
create table public.likes (
  user_id uuid references public.profiles(id) on delete cascade,
  artwork_id uuid references public.artworks(id) on delete cascade,
  primary key (user_id, artwork_id)
);
create table public.saves (
  user_id uuid references public.profiles(id) on delete cascade,
  artwork_id uuid references public.artworks(id) on delete cascade,
  primary key (user_id, artwork_id)
);

-- Perfil automático al registrarse
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Seguridad por filas (RLS)
alter table public.profiles enable row level security;
alter table public.artworks enable row level security;
alter table public.likes enable row level security;
alter table public.saves enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update_own on public.profiles for update to authenticated using (auth.uid() = id);

create policy artworks_read on public.artworks for select to authenticated using (true);
create policy artworks_insert_own on public.artworks for insert to authenticated with check (auth.uid() = user_id);
create policy artworks_update_own on public.artworks for update to authenticated using (auth.uid() = user_id);
create policy artworks_delete_own on public.artworks for delete to authenticated using (auth.uid() = user_id);

create policy likes_read on public.likes for select to authenticated using (true);
create policy likes_insert_own on public.likes for insert to authenticated with check (auth.uid() = user_id);
create policy likes_delete_own on public.likes for delete to authenticated using (auth.uid() = user_id);

create policy saves_read_own on public.saves for select to authenticated using (auth.uid() = user_id);
create policy saves_insert_own on public.saves for insert to authenticated with check (auth.uid() = user_id);
create policy saves_delete_own on public.saves for delete to authenticated using (auth.uid() = user_id);

-- Almacenamiento de imágenes (lectura pública, subida solo a tu carpeta)
insert into storage.buckets (id, name, public) values ('artworks', 'artworks', true)
  on conflict (id) do nothing;
create policy artworks_img_read on storage.objects for select using (bucket_id = 'artworks');
create policy artworks_img_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'artworks' and (storage.foldername(name))[1] = auth.uid()::text);
