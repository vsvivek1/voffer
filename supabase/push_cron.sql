-- Run once in the Supabase SQL editor after deploying the push-alerts
-- function. It calls the function every minute to send new alerts.
--
-- Before running, store two secrets in Vault (Project Settings > Vault, or
-- the SQL below with your values):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service role key>', 'service_role_key');

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'push-alerts',
  '* * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/push-alerts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
