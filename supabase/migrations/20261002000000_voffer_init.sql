-- Voffer: firms publish offers, customers reserve them and pay at the firm.

create type public.user_role as enum ('customer', 'firm');
create type public.order_status as enum ('reserved', 'fulfilled', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'customer',
  display_name text not null check (char_length(display_name) between 1 and 120),
  created_at timestamptz not null default now()
);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.profiles (id) on delete cascade,
  firm_name text not null default '',
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '',
  price numeric(12, 2) not null check (price >= 0),
  original_price numeric(12, 2) check (original_price is null or original_price >= price),
  category text not null default 'Other',
  image_url text,
  quantity_available integer check (quantity_available is null or quantity_available >= 0),
  expires_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index offers_feed_idx on public.offers (created_at desc)
  where is_active;
create index offers_firm_idx on public.offers (firm_id, created_at desc);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers (id) on delete restrict,
  offer_title text not null,
  firm_id uuid not null references public.profiles (id) on delete cascade,
  firm_name text not null,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  customer_name text not null,
  quantity integer not null check (quantity between 1 and 100),
  unit_price numeric(12, 2) not null,
  status public.order_status not null default 'reserved',
  code text not null,
  created_at timestamptz not null default now()
);

create index orders_customer_idx on public.orders (customer_id, created_at desc);
create index orders_firm_idx on public.orders (firm_id, created_at desc);

-- Create a profile from sign-up metadata.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, role, display_name)
  values (
    new.id,
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'customer'),
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Stamp the firm's name on its offers so the feed needs no join.
create function public.set_offer_firm_name() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  select display_name into new.firm_name from public.profiles where id = new.firm_id;
  return new;
end;
$$;

create trigger offers_set_firm_name
  before insert on public.offers
  for each row execute function public.set_offer_firm_name();

-- Atomically reserve stock and create an order for the calling customer.
create function public.place_order(p_offer_id uuid, p_quantity integer)
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
  if v_offer.id is null or not v_offer.is_active or v_offer.expires_at <= now() then
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

revoke execute on function public.place_order(uuid, integer) from public, anon;
grant execute on function public.place_order(uuid, integer) to authenticated;

-- Row level security
alter table public.profiles enable row level security;
alter table public.offers enable row level security;
alter table public.orders enable row level security;

create policy "Users read their own profile" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Users update their own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid()));
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

create policy "Anyone reads live offers" on public.offers
  for select to anon, authenticated
  using (is_active and expires_at > now());
create policy "Firms read their own offers" on public.offers
  for select to authenticated using (firm_id = (select auth.uid()));
create policy "Firms publish offers" on public.offers
  for insert to authenticated
  with check (
    firm_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'firm')
  );
create policy "Firms update their own offers" on public.offers
  for update to authenticated using (firm_id = (select auth.uid()));
revoke update on public.offers from authenticated;
grant update (title, description, price, original_price, category, image_url,
  quantity_available, expires_at, is_active) on public.offers to authenticated;

create policy "Customers read their orders" on public.orders
  for select to authenticated using (customer_id = (select auth.uid()));
create policy "Firms read orders for their offers" on public.orders
  for select to authenticated using (firm_id = (select auth.uid()));
create policy "Firms update order status" on public.orders
  for update to authenticated using (firm_id = (select auth.uid()));
revoke insert, update, delete on public.orders from anon, authenticated;
grant update (status) on public.orders to authenticated;
