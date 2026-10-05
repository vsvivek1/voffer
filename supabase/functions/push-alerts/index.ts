// Sends a phone notification for each new alert. Runs every minute from
// pg_cron (see supabase/push_cron.sql).
//
// Secrets: FIREBASE_SERVICE_ACCOUNT holds the Firebase service account JSON.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5';

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type ClaimedAlert = {
  alert_id: string;
  title: string;
  body: string;
  shop_id: string;
  tokens: string[];
};

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

let cachedToken: { value: string; expiresAt: number } | null = null;

// An OAuth access token for FCM, signed with the service account key.
async function accessToken(account: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`Google token request failed: ${res.status}`);
  const json = await res.json();
  cachedToken = {
    value: json.access_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  };
  return cachedToken.value;
}

// Sends one notification. Returns false when the token is no longer valid.
async function send(
  account: ServiceAccount,
  token: string,
  alert: ClaimedAlert,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${await accessToken(account)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: alert.title, body: alert.body },
          data: { shop_id: alert.shop_id, alert_id: alert.alert_id },
          android: { priority: 'high' },
        },
      }),
    },
  );
  if (res.ok) return true;
  const text = await res.text();
  if (res.status === 404 || text.includes('UNREGISTERED') || text.includes('INVALID_ARGUMENT')) {
    return false;
  }
  console.error(`FCM send failed (${res.status}): ${text}`);
  return true;
}

Deno.serve(async () => {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!raw) {
    return new Response('FIREBASE_SERVICE_ACCOUNT is not set', { status: 500 });
  }
  const account: ServiceAccount = JSON.parse(raw);

  const { data, error } = await supabase.rpc('claim_alerts_for_push', {
    p_limit: 500,
  });
  if (error) return new Response(error.message, { status: 500 });

  const alerts = (data ?? []) as ClaimedAlert[];
  const stale = new Set<string>();
  let sent = 0;
  for (const alert of alerts) {
    for (const token of alert.tokens) {
      if (stale.has(token)) continue;
      if (await send(account, token, alert)) {
        sent++;
      } else {
        stale.add(token);
      }
    }
  }
  if (stale.size > 0) {
    await supabase.from('device_tokens').delete().in('token', [...stale]);
  }

  return Response.json({ alerts: alerts.length, sent, removed: stale.size });
});
