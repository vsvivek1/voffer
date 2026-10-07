-- Account deletion: the delete-account Edge Function removes the caller's
-- photos and then deletes their auth user. Deleting the auth user removes
-- their profile, which cascades to everything that is only theirs: shop,
-- offers, follows, alerts and device tokens.
--
-- Orders involve two people, so they are kept for the other side and
-- stripped of the deleted person instead:
--   * a deleted customer's orders stay in the shop's sales history with the
--     customer shown as "Deleted user";
--   * a deleted shop's orders stay in each customer's order history (the
--     order already carries the offer title and shop name), and any order
--     still waiting to be redeemed is cancelled.

-- Orders may outlive either party, or the offer they were for.
alter table public.orders alter column customer_id drop not null;
alter table public.orders alter column firm_id drop not null;
alter table public.orders alter column offer_id drop not null;

alter table public.orders drop constraint orders_customer_id_fkey;
alter table public.orders add constraint orders_customer_id_fkey
  foreign key (customer_id) references public.profiles (id) on delete set null;

alter table public.orders drop constraint orders_firm_id_fkey;
alter table public.orders add constraint orders_firm_id_fkey
  foreign key (firm_id) references public.profiles (id) on delete set null;

-- Was "on delete restrict", which made deleting a firm with any orders fail.
alter table public.orders drop constraint orders_offer_id_fkey;
alter table public.orders add constraint orders_offer_id_fkey
  foreign key (offer_id) references public.offers (id) on delete set null;

-- Runs for every profile delete, whether from the app, the dashboard or the
-- admin API, before the foreign keys clear the ids.
create function public.anonymize_orders_of_deleted_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.orders
    set customer_name = 'Deleted user'
    where customer_id = old.id;
  update public.orders
    set status = 'cancelled'
    where firm_id = old.id and status = 'reserved';
  return old;
end;
$$;

revoke execute on function public.anonymize_orders_of_deleted_profile() from public, anon, authenticated;

create trigger profiles_anonymize_orders
  before delete on public.profiles
  for each row execute function public.anonymize_orders_of_deleted_profile();
