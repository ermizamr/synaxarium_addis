import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../lib/main.dart', import.meta.url), 'utf8');
const urlMatch = source.match(/url:\s*'([^']+)'/);
const keyMatch = source.match(/anonKey:\s*\n\s*'([^']+)'/);
if (!urlMatch || !keyMatch) throw new Error('Unable to parse Supabase config from lib/main.dart');

const supabaseUrl = urlMatch[1];
const anonKey = keyMatch[1];

const rand = () => Math.floor(Math.random() * 1_000_000_000).toString().padStart(9, '0');
const phone = `09${rand()}`;
const deviceId = `e2e-reinstall-${Date.now()}`;

const post = async (path, body, token) => {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anonKey,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });

  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  return { status: response.status, json };
};

const signupAnon = async () => {
  const res = await post('/auth/v1/signup', {});
  const token = res.json?.access_token ?? res.json?.session?.access_token;
  const userId = res.json?.user?.id;
  if (!token || !userId) {
    throw new Error(`Anonymous signup failed: ${JSON.stringify(res)}`);
  }
  return { token, userId, res };
};

const oldAccount = await signupAnon();

const setupSteps = [];
setupSteps.push({
  step: 'old_signup',
  status: oldAccount.res.status,
  userId: oldAccount.userId,
});

setupSteps.push(await post('/rest/v1/users?on_conflict=id', [{ id: oldAccount.userId }], oldAccount.token));
setupSteps.push(
  await post(
    '/rest/v1/user_profiles?on_conflict=user_id',
    [
      {
        user_id: oldAccount.userId,
        name: 'E2E Active User',
        phone,
        tier: 'normal',
      },
    ],
    oldAccount.token,
  ),
);
setupSteps.push(
  await post(
    '/rest/v1/subscriptions',
    [
      {
        user_id: oldAccount.userId,
        status: 'active',
        current_period_end: null,
      },
    ],
    oldAccount.token,
  ),
);

const newInstall = await signupAnon();

const recovery = await post(
  '/rest/v1/rpc/claim_account_by_phone',
  {
    p_phone: phone,
    p_device_id: deviceId,
    p_device_info: { source: 'e2e_reinstall' },
  },
  newInstall.token,
);

const postRecoveryAllow = await post(
  '/rest/v1/rpc/allow_device_login',
  {
    p_user_id: newInstall.userId,
    p_device_id: deviceId,
    p_device_info: { phone, source: 'e2e_reinstall' },
  },
  newInstall.token,
);

const mismatchCheck = await post(
  '/rest/v1/rpc/allow_device_login',
  {
    p_user_id: newInstall.userId,
    p_device_id: `${deviceId}-mismatch`,
    p_device_info: { phone: '0900000000', source: 'e2e_reinstall' },
  },
  newInstall.token,
);

const pass =
  recovery.status === 200 &&
  recovery.json?.recovered === true &&
  postRecoveryAllow.status === 200 &&
  postRecoveryAllow.json?.allowed === true &&
  mismatchCheck.status === 200 &&
  mismatchCheck.json?.reason === 'phone_mismatch';

const report = {
  scenario: 'active_user_reinstall_recovery',
  phone,
  deviceId,
  oldUserId: oldAccount.userId,
  newUserId: newInstall.userId,
  setupStatuses: setupSteps.map((s, idx) => ({ index: idx + 1, status: s.status ?? s?.step })),
  recovery,
  postRecoveryAllow,
  mismatchCheck,
  pass,
};

console.log(JSON.stringify(report, null, 2));
if (!pass) process.exitCode = 1;
