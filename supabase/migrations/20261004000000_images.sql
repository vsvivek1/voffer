-- Phase 3: firms upload offer photos and a shop logo to Storage instead of
-- pasting image links.

-- Public bucket: anyone can view images, only their owner can write them.
-- Each firm writes under a folder named after its user id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'voffer-images', 'voffer-images', true, 1048576,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "Firms upload images to their own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'voffer-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'firm')
  );

create policy "Firms replace their own images" on storage.objects
  for update to authenticated
  using (bucket_id = 'voffer-images' and owner_id = (select auth.uid())::text);

create policy "Firms delete their own images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'voffer-images' and owner_id = (select auth.uid())::text);

-- Shop logo.
alter table public.shops add column logo_url text
  check (logo_url is null or char_length(logo_url) <= 1000);

alter table public.offers add constraint offers_image_url_length
  check (image_url is null or char_length(image_url) <= 1000);

drop function public.save_shop(text, text, text, text, text, double precision, double precision);

-- Create or update the calling firm's shop. The shop name becomes the firm's
-- display name and is stamped on its offers.
create function public.save_shop(
  p_name text,
  p_category text,
  p_address text,
  p_phone text,
  p_hours text,
  p_lat double precision,
  p_lng double precision,
  p_logo_url text default null
)
returns public.shops
language plpgsql security definer set search_path = '' as $$
declare
  v_shop public.shops;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'firm'
  ) then
    raise exception 'Only firm accounts can have a shop.';
  end if;
  if v_name = '' then
    raise exception 'Enter the shop name.';
  end if;
  if btrim(coalesce(p_address, '')) = '' then
    raise exception 'Enter the shop address.';
  end if;
  if p_lat is null or p_lng is null
    or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Set the shop location on the map.';
  end if;

  insert into public.shops (
    id, name, category, address, phone, hours, lat, lng, location, logo_url
  ) values (
    auth.uid(), v_name, coalesce(nullif(btrim(p_category), ''), 'Other'),
    btrim(p_address), nullif(btrim(p_phone), ''), nullif(btrim(p_hours), ''),
    p_lat, p_lng,
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    nullif(btrim(p_logo_url), '')
  )
  on conflict (id) do update set
    name = excluded.name,
    category = excluded.category,
    address = excluded.address,
    phone = excluded.phone,
    hours = excluded.hours,
    lat = excluded.lat,
    lng = excluded.lng,
    location = excluded.location,
    logo_url = excluded.logo_url,
    updated_at = now()
  returning * into v_shop;

  update public.profiles set display_name = v_name
    where id = auth.uid() and display_name <> v_name;
  update public.offers set firm_name = v_name
    where firm_id = auth.uid() and firm_name <> v_name;

  return v_shop;
end;
$$;

revoke execute on function public.save_shop(text, text, text, text, text, double precision, double precision, text) from public, anon;
grant execute on function public.save_shop(text, text, text, text, text, double precision, double precision, text) to authenticated;
