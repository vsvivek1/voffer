-- Phone push: each signed-in phone registers its Firebase token, and the
-- push-alerts Edge Function sends a notification for each new alert.

create table public.device_tokens (
  token text primary key check (char_length(token) between 1 and 4096),
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "Users read their device tokens" on public.device_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users remove their device tokens" on public.device_tokens
  for delete to authenticated using (user_id = (select auth.uid()));
revoke all on public.device_tokens from anon;
revoke insert, update on public.device_tokens from authenticated;

-- Registers the calling user's phone. A token moves to whoever signed in on
-- that phone most recently.
create function public.save_device_token(p_token text, p_platform text default 'android')
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  insert into public.device_tokens (token, user_id, platform)
  values (p_token, auth.uid(), coalesce(nullif(btrim(p_platform), ''), 'android'))
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

revoke execute on function public.save_device_token(text, text) from public, anon;
grant execute on function public.save_device_token(text, text) to authenticated;

-- When an alert was handed to the push sender. Alerts from before this
-- migration count as sent so nobody gets a burst of old news.
alter table public.alerts add column pushed_at timestamptz;
update public.alerts set pushed_at = now();

create index alerts_unpushed_idx on public.alerts (visible_at)
  where pushed_at is null;

-- Claims up to p_limit visible, unsent alerts for the push sender, with the
-- tokens to send each to. Alerts older than a day are dropped unsent.
-- Only the service role (the Edge Function) may call it.
create function public.claim_alerts_for_push(p_limit integer default 500)
returns table (alert_id uuid, title text, body text, shop_id uuid, tokens text[])
language plpgsql security definer set search_path = '' as $$
begin
  return query
  with claimed as (
    update public.alerts a
      set pushed_at = now()
      where a.id in (
        select id from public.alerts
        where pushed_at is null and visible_at <= now()
        order by visible_at
        limit least(greatest(coalesce(p_limit, 500), 1), 1000)
        for update skip locked
      )
    returning a.id, a.user_id, a.title, a.body, a.shop_id, a.visible_at
  )
  select c.id, c.title, c.body, c.shop_id,
    array(select d.token from public.device_tokens d where d.user_id = c.user_id)
  from claimed c
  where c.visible_at > now() - interval '1 day';
end;
$$;

revoke execute on function public.claim_alerts_for_push(integer) from public, anon, authenticated;
grant execute on function public.claim_alerts_for_push(integer) to service_role;
