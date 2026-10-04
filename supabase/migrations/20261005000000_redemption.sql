-- Phase 4: customers show a QR code for each order and the shop scans it to
-- redeem the order. Redemption goes through redeem_order so a code can only
-- be used once, at the shop that sold it.

alter table public.orders add column redeemed_at timestamptz;

-- Order status now changes only through redeem_order.
revoke update on public.orders from authenticated;
drop policy "Firms update order status" on public.orders;

-- A code identifies one open order at its shop.
create unique index orders_open_code_idx on public.orders (firm_id, code)
  where status = 'reserved';

-- Same as before, but the code is retried until no other open order at the
-- shop uses it.
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
    quantity, unit_price, code
  ) values (
    v_offer.id, v_offer.title, v_offer.firm_id, v_offer.firm_name,
    v_customer.id, v_customer.display_name, p_quantity, v_offer.price, v_code
  ) returning * into v_order;

  return v_order;
end;
$$;

-- Marks the calling shop's open order with this code as fulfilled.
create function public.redeem_order(p_code text)
returns public.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_order public.orders;
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'firm'
  ) then
    raise exception 'Only shops can redeem orders.';
  end if;
  if v_code = '' then
    raise exception 'Enter the order code.';
  end if;

  select * into v_order from public.orders
    where firm_id = auth.uid() and code = v_code
    order by (status = 'reserved') desc, created_at desc
    limit 1
    for update;

  if v_order.id is null then
    raise exception 'No order with code % at your shop.', v_code;
  end if;
  if v_order.status = 'fulfilled' then
    raise exception 'Order % was already redeemed.', v_code;
  end if;
  if v_order.status = 'cancelled' then
    raise exception 'Order % was cancelled.', v_code;
  end if;

  update public.orders
    set status = 'fulfilled', redeemed_at = now()
    where id = v_order.id
    returning * into v_order;
  return v_order;
end;
$$;

revoke execute on function public.redeem_order(text) from public, anon;
grant execute on function public.redeem_order(text) to authenticated;
