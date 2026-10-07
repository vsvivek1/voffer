// Permanently deletes the calling user's account. The app calls it from the
// "Delete account" menu item with the user's session.
//
// 1. Removes the user's photos from the voffer-images bucket (everything
//    under the folder named after their user id). Auth refuses to delete a
//    user who still owns Storage objects.
// 2. Deletes the auth user. That removes their profile, which cascades to
//    their shop, offers, follows, alerts and device tokens; their orders are
//    anonymized for the other party (see
//    supabase/migrations/20261008000000_account_deletion.sql).
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from 'npm:@supabase/supabase-js@2';

const IMAGE_BUCKET = 'voffer-images';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

// Removes every object in the user's folder, a page at a time.
async function deletePhotos(userId: string): Promise<number> {
  const bucket = supabase.storage.from(IMAGE_BUCKET);
  let removed = 0;
  // Bounded so a remove that silently keeps nothing can't loop forever.
  for (let page = 0; page < 100; page++) {
    const { data, error } = await bucket.list(userId, { limit: 1000 });
    if (error) throw new Error(`Could not list photos: ${error.message}`);
    // Entries with a null id are folders; uploads are never nested.
    const paths = (data ?? [])
      .filter((f) => f.id !== null)
      .map((f) => `${userId}/${f.name}`);
    if (paths.length === 0) return removed;
    const { error: removeError } = await bucket.remove(paths);
    if (removeError) {
      throw new Error(`Could not delete photos: ${removeError.message}`);
    }
    removed += paths.length;
  }
  throw new Error('Too many photos to delete in one request.');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Use POST.' }, 405);

  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'Sign in first.' }, 401);

  // Resolves the user from their own access token, so a caller can only ever
  // delete themselves.
  const { data: { user }, error: userError } = await supabase.auth.getUser(token);
  if (userError || !user) return json({ error: 'Sign in first.' }, 401);

  try {
    const photos = await deletePhotos(user.id);
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) throw new Error(`Could not delete account: ${error.message}`);
    return json({ deleted: true, photos });
  } catch (e) {
    console.error(`delete-account failed for ${user.id}:`, e);
    return json(
      { error: 'Could not delete your account. Please try again.' },
      500,
    );
  }
});
