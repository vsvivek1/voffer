-- Phase 5: customers follow shops and get an alert when a followed shop
-- publishes an offer. Shops can be in India or the USA, and prices carry the
-- shop's currency.

-- Markets ------------------------------------------------------------------

alter table public.shops add column country text not null default 'IN'
  check (country in ('IN', 'US'));
alter table public.offers add column currency text not null default 'INR'
  check (currency in ('INR', 'USD'));
alter table public.orders add column currency text not null default 'INR'
  check (currency in ('INR', 'USD'));

create function public.currency_for_country(p_country text)
returns text
language sql immutable set search_path = '' as $$
  select case p_country when 'US' then 'USD' else 'INR' end;
$$;

-- Stamp the firm's name and its shop's currency on new offers.
create or replace function public.set_offer_firm_name() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  select display_name into new.firm_name from public.profiles where id = new.firm_id;
  new.currency := coalesce(
    (select public.currency_for_country(country) from public.shops where id = new.firm_id),
    'INR'
  );
  return new;
end;
$$;

drop function public.save_shop(text, text, text, text, text, double precision, double precision, text);

-- Create or update the calling firm's shop. The shop name becomes the firm's
-- display name and is stamped on its offers, along with its currency.
-- p_country defaults to the shop's current country, or India.
create function public.save_shop(
  p_name text,
  p_category text,
  p_address text,
  p_phone text,
  p_hours text,
  p_lat double precision,
  p_lng double precision,
  p_logo_url text default null,
  p_country text default null
)
returns public.shops
language plpgsql security definer set search_path = '' as $$
declare
  v_shop public.shops;
  v_name text := btrim(coalesce(p_name, ''));
  v_country text := coalesce(
    nullif(upper(btrim(p_country)), ''),
    (select country from public.shops where id = auth.uid()),
    'IN'
  );
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
  if v_country not in ('IN', 'US') then
    raise exception 'Shops can be in India or the USA.';
  end if;

  insert into public.shops (
    id, name, category, address, phone, hours, lat, lng, location, logo_url,
    country
  ) values (
    auth.uid(), v_name, coalesce(nullif(btrim(p_category), ''), 'Other'),
    btrim(p_address), nullif(btrim(p_phone), ''), nullif(btrim(p_hours), ''),
    p_lat, p_lng,
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    nullif(btrim(p_logo_url), ''), v_country
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
    country = excluded.country,
    updated_at = now()
  returning * into v_shop;

  update public.profiles set display_name = v_name
    where id = auth.uid() and display_name <> v_name;
  update public.offers
    set firm_name = v_name, currency = public.currency_for_country(v_country)
    where firm_id = auth.uid()
      and (firm_name <> v_name or currency <> public.currency_for_country(v_country));

  return v_shop;
end;
$$;

revoke execute on function public.save_shop(text, text, text, text, text, double precision, double precision, text, text) from public, anon;
grant execute on function public.save_shop(text, text, text, text, text, double precision, double precision, text, text) to authenticated;

-- Same as before, plus the order records the offer's currency.
create or replace function public.place_order(p_offer_id uuid, p_quantity integer)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_offer public.offers;
  v_customer public.profiles;
  v_order public.orders;
  v_code text;
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

  loop
    v_code := upper(substr(translate(encode(extensions.gen_random_bytes(8), 'base64'), '+/=0O1IL', ''), 1, 6));
    exit when char_length(v_code) = 6 and not exists (
      select 1 from public.orders
      where firm_id = v_offer.firm_id and code = v_code and status = 'reserved'
    );
  end loop;

  insert into public.orders (
    offer_id, offer_title, firm_id, firm_name, customer_id, customer_name,
    quantity, unit_price, currency, code
  ) values (
    v_offer.id, v_offer.title, v_offer.firm_id, v_offer.firm_name,
    v_customer.id, v_customer.display_name, p_quantity, v_offer.price,
    v_offer.currency, v_code
  ) returning * into v_order;

  return v_order;
end;
$$;

-- Same as before, plus each offer's currency.
drop function public.offers_nearby(double precision, double precision, double precision, text, text);

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
  currency text,
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
    o.original_price, o.currency, o.category, o.image_url, o.quantity_available,
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
  order by 16, o.created_at desc
  limit 200;
$$;

grant execute on function public.offers_nearby(double precision, double precision, double precision, text, text) to anon, authenticated;

-- Follows ------------------------------------------------------------------

create table public.follows (
  customer_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, shop_id)
);

create index follows_shop_idx on public.follows (shop_id);

alter table public.follows enable row level security;

create policy "Customers read their follows" on public.follows
  for select to authenticated using (customer_id = (select auth.uid()));
create policy "Customers follow shops" on public.follows
  for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'customer')
  );
create policy "Customers unfollow shops" on public.follows
  for delete to authenticated using (customer_id = (select auth.uid()));
revoke all on public.follows from anon;
revoke update on public.follows from authenticated;

-- How many customers follow a shop. Anyone can see the count, not who.
create function public.shop_follower_count(p_shop_id uuid)
returns integer
language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.follows where shop_id = p_shop_id;
$$;

grant execute on function public.shop_follower_count(uuid) to anon, authenticated;

-- Alerts -------------------------------------------------------------------

-- One row per follower per new offer. A scheduled offer's alert shows up
-- when the offer starts.
create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  offer_id uuid not null references public.offers (id) on delete cascade,
  title text not null,
  body text not null,
  visible_at timestamptz not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index alerts_user_idx on public.alerts (user_id, visible_at desc);

alter table public.alerts enable row level security;

create policy "Users read their alerts" on public.alerts
  for select to authenticated
  using (user_id = (select auth.uid()) and visible_at <= now());
create policy "Users mark their alerts read" on public.alerts
  for update to authenticated
  using (user_id = (select auth.uid()) and visible_at <= now());
revoke all on public.alerts from anon;
revoke insert, update, delete on public.alerts from authenticated;
grant update (read_at) on public.alerts to authenticated;

create function public.alert_followers() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.alerts (user_id, shop_id, offer_id, title, body, visible_at)
  select f.customer_id, new.firm_id, new.id,
    new.firm_name || ' has a new offer', new.title, new.starts_at
  from public.follows f
  where f.shop_id = new.firm_id;
  return null;
end;
$$;

create trigger offers_alert_followers
  after insert on public.offers
  for each row when (new.is_active)
  execute function public.alert_followers();
