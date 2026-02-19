import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../lib/main.dart', import.meta.url), 'utf8');
const urlMatch = source.match(/url:\s*'([^']+)'/);
const keyMatch = source.match(/anonKey:\s*\n\s*'([^']+)'/);
if (!urlMatch || !keyMatch) throw new Error('Missing Supabase config in main.dart');

const supabaseUrl = urlMatch[1];
const anonKey = keyMatch[1];

const post = async (path, body, token) => {
  const res = await fetch(`${supabaseUrl}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anonKey,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, json };
};

const signup = await post('/auth/v1/signup', {});
const token = signup.json?.access_token ?? signup.json?.session?.access_token;
const userId = signup.json?.user?.id;
if (!token || !userId) {
  throw new Error(`Anonymous signup failed: ${JSON.stringify(signup)}`);
}

const phone = `09${Math.floor(Math.random() * 1_000_000_000).toString().padStart(9, '0')}`;

const upsertUser = await post('/rest/v1/users?on_conflict=id', [{ id: userId }], token);
const upsertProfile = await post('/rest/v1/user_profiles?on_conflict=user_id', [{
  user_id: userId,
  name: 'E2E Phone Binding',
  phone,
  tier: 'normal',
}], token);
const insertSub = await post('/rest/v1/subscriptions', [{
  user_id: userId,
  status: 'active',
  current_period_end: null,
}], token);

const mismatch = await post('/rest/v1/rpc/allow_device_login', {
  p_user_id: userId,
  p_device_id: `e2e-phone-binding-${Date.now()}`,
  p_device_info: { phone: '0900000000', source: 'e2e' },
}, token);

const match = await post('/rest/v1/rpc/allow_device_login', {
  p_user_id: userId,
  p_device_id: `e2e-phone-binding-${Date.now()}-ok`,
  p_device_info: { phone, source: 'e2e' },
}, token);

const report = {
  setup: {
    upsertUserStatus: upsertUser.status,
    upsertProfileStatus: upsertProfile.status,
    insertSubscriptionStatus: insertSub.status,
  },
  mismatch,
  match,
  pass: mismatch.status === 200 && mismatch.json?.reason === 'phone_mismatch' && match.status === 200 && match.json?.allowed === true,
};

console.log(JSON.stringify(report, null, 2));
if (!report.pass) process.exitCode = 1;
