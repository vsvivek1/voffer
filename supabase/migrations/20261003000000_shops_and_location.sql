-- Phase 2: every firm has one shop with a map location, offers can start
-- later than they are published, and customers find offers near them.

create extension if not exists postgis with schema extensions;

-- A firm's shop shares its id with the firm's profile, so offers.firm_id
-- doubles as the shop id.
create table public.shops (
  id uuid primary key references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  category text not null default 'Other',
  address text not null check (char_length(address) between 1 and 300),
  phone text check (phone is null or char_length(phone) <= 30),
  hours text check (hours is null or char_length(hours) <= 120),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  location extensions.geography(Point, 4326) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index shops_location_idx on public.shops using gist (location);

alter table public.shops enable row level security;

create policy "Anyone reads shops" on public.shops
  for select to anon, authenticated using (true);
-- Shops are written only through save_shop.
revoke insert, update, delete on public.shops from anon, authenticated;

-- Create or update the calling firm's shop. The shop name becomes the firm's
-- display name and is stamped on its offers.
create function public.save_shop(
  p_name text,
  p_category text,
  p_address text,
  p_phone text,
  p_hours text,
  p_lat double precision,
  p_lng double precision
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
    id, name, category, address, phone, hours, lat, lng, location
  ) values (
    auth.uid(), v_name, coalesce(nullif(btrim(p_category), ''), 'Other'),
    btrim(p_address), nullif(btrim(p_phone), ''), nullif(btrim(p_hours), ''),
    p_lat, p_lng,
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography
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
    updated_at = now()
  returning * into v_shop;

  update public.profiles set display_name = v_name
    where id = auth.uid() and display_name <> v_name;
  update public.offers set firm_name = v_name
    where firm_id = auth.uid() and firm_name <> v_name;

  return v_shop;
end;
$$;

revoke execute on function public.save_shop(text, text, text, text, text, double precision, double precision) from public, anon;
grant execute on function public.save_shop(text, text, text, text, text, double precision, double precision) to authenticated;

-- Offers can be scheduled to start later.
alter table public.offers add column starts_at timestamptz not null default now();
alter table public.offers add constraint offers_starts_before_expiry
  check (starts_at < expires_at);
grant update (starts_at) on public.offers to authenticated;

drop policy "Anyone reads live offers" on public.offers;
create policy "Anyone reads live offers" on public.offers
  for select to anon, authenticated
  using (is_active and starts_at <= now() and expires_at > now());

-- Firms need a shop before they can publish.
drop policy "Firms publish offers" on public.offers;
create policy "Firms publish offers" on public.offers
  for insert to authenticated
  with check (
    firm_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'firm')
    and exists (select 1 from public.shops s where s.id = (select auth.uid()))
  );

-- Orders must also respect the start time.
create or replace function public.place_order(p_offer_id uuid, p_quantity integer)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_offer public.offers;
  v_customer public.profiles;
  v_order public.orders;
begin
  if p_quantity is null or p_quantity < 1 or p_quantity > 100 then
    raise exception 'Choose between 1 and 100.';
  end if;

  select * into v_customer from public.profiles where id = auth.uid();
  if v_customer.id is null then
    raise exception 'Sign in to buy offers.';
  end if;

  select * into v_offer from public.offers where id = p_offer_id for update;
  if v_offer.id is null or not v_offer.is_active
    or v_offer.starts_at > now() or v_offer.expires_at <= now() then
    raise exception 'This offer is no longer available.';
  end if;
  if v_offer.quantity_available is not null then
    if v_offer.quantity_available < p_quantity then
      raise exception 'Only % left.', v_offer.quantity_available;
    end if;
    update public.offers
      set quantity_available = quantity_available - p_quantity
      where id = v_offer.id;
  end if;

  insert into public.orders (
    offer_id, offer_title, firm_id, firm_name, customer_id, customer_name,
    quantity, unit_price, code
  ) values (
    v_offer.id, v_offer.title, v_offer.firm_id, v_offer.firm_name,
    v_customer.id, v_customer.display_name, p_quantity, v_offer.price,
    upper(substr(translate(encode(extensions.gen_random_bytes(8), 'base64'), '+/=0O1IL', ''), 1, 6))
  ) returning * into v_order;

  return v_order;
end;
$$;

-- Live offers within p_radius_km of a point, nearest first. Runs as the
-- caller, so the offers and shops read policies still apply.
create function public.offers_nearby(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 10,
  p_category text default null,
  p_query text default null
)
returns table (
  id uuid,
  firm_id uuid,
  firm_name text,
  title text,
  description text,
  price numeric,
  original_price numeric,
  category text,
  image_url text,
  quantity_available integer,
  starts_at timestamptz,
  expires_at timestamptz,
  is_active boolean,
  created_at timestamptz,
  distance_km double precision,
  shop_address text
)
language sql stable set search_path = '' as $$
  with here as (
    select extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography as point
  ), q as (
    select '%' || replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%' as pattern,
      btrim(coalesce(p_query, '')) = '' as empty
  )
  select o.id, o.firm_id, o.firm_name, o.title, o.description, o.price,
    o.original_price, o.category, o.image_url, o.quantity_available,
    o.starts_at, o.expires_at, o.is_active, o.created_at,
    extensions.st_distance(s.location, here.point) / 1000.0,
    s.address
  from public.offers o
  join public.shops s on s.id = o.firm_id
  cross join here
  cross join q
  where o.is_active
    and o.starts_at <= now()
    and o.expires_at > now()
    and extensions.st_dwithin(
      s.location, here.point, least(greatest(coalesce(p_radius_km, 10), 0.5), 100) * 1000
    )
    and (p_category is null or o.category = p_category)
    and (q.empty or o.title ilike q.pattern or o.firm_name ilike q.pattern
      or o.description ilike q.pattern)
  order by 15, o.created_at desc
  limit 200;
$$;

grant execute on function public.offers_nearby(double precision, double precision, double precision, text, text) to anon, authenticated;
