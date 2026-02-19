import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../lib/main.dart', import.meta.url), 'utf8');
const urlMatch = source.match(/url:\s*'([^']+)'/);
const keyMatch = source.match(/anonKey:\s*\n\s*'([^']+)'/);

if (!urlMatch || !keyMatch) {
  throw new Error('Could not parse Supabase url/anon key from lib/main.dart');
}

const supabaseUrl = urlMatch[1];
const anonKey = keyMatch[1];
const functionBase = `${supabaseUrl}/functions/v1/make-server-74ada437`;

const results = [];

const addResult = (name, ok, details) => {
  results.push({ name, ok, details });
};

const postJson = async (url, body, headers = {}) => {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anonKey,
      ...headers,
    },
    body: JSON.stringify(body),
  });

  let json = null;
  try {
    json = await response.json();
  } catch {
    json = { parse_error: true };
  }

  return { status: response.status, json };
};

const getJson = async (url, headers = {}) => {
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      apikey: anonKey,
      ...headers,
    },
  });
  let json = null;
  try {
    json = await response.json();
  } catch {
    json = { parse_error: true };
  }
  return { status: response.status, json };
};

const randomPhone = `9${Math.floor(Math.random() * 1_000_000_0000)
  .toString()
  .padStart(10, '0')}`;

let accessToken = null;
let userId = null;

// 1) Anonymous sign in
{
  const res = await postJson(`${supabaseUrl}/auth/v1/signup`, {});
  accessToken = res.json?.access_token ?? res.json?.session?.access_token ?? null;
  userId = res.json?.user?.id ?? null;
  addResult('auth_anonymous_signup', !!accessToken && !!userId, {
    status: res.status,
    hasAccessToken: !!accessToken,
    hasUserId: !!userId,
    error: res.json?.error_description ?? res.json?.msg ?? null,
  });
}

if (accessToken && userId) {
  const authHeaders = {
    Authorization: `Bearer ${accessToken}`,
  };

  // 2) get_user_id_by_phone unknown
  {
    const res = await postJson(`${supabaseUrl}/rest/v1/rpc/get_user_id_by_phone`, { p_phone: randomPhone }, authHeaders);
    addResult('rpc_get_user_id_by_phone_unknown', res.status === 200, {
      status: res.status,
      returned: res.json,
    });
  }

  // 3) claim_account_by_phone unknown
  {
    const res = await postJson(
      `${supabaseUrl}/rest/v1/rpc/claim_account_by_phone`,
      {
        p_phone: randomPhone,
        p_device_id: `e2e-${Date.now()}`,
        p_device_info: { source: 'e2e_smoke' },
      },
      authHeaders,
    );

    addResult(
      'rpc_claim_account_by_phone_unknown',
      res.status === 200 && res.json?.recovered === false && res.json?.reason === 'not_found',
      { status: res.status, response: res.json },
    );
  }

  // 4) allow_device_login without phone should be blocked by phone_required
  {
    const res = await postJson(
      `${supabaseUrl}/rest/v1/rpc/allow_device_login`,
      {
        p_user_id: userId,
        p_device_id: `e2e-device-${Date.now()}`,
        p_device_info: {},
      },
      authHeaders,
    );

    addResult(
      'rpc_allow_device_login_requires_phone',
      res.status === 200 && (res.json?.reason === 'phone_required' || res.json?.reason === 'no_active_subscription' || res.json?.reason === 'screenshot_not_approved'),
      { status: res.status, response: res.json },
    );
  }
}

// 5) Admin health
{
  const res = await getJson(`${functionBase}/health`);
  addResult('admin_function_health', res.status === 200 && res.json?.status === 'ok', {
    status: res.status,
    response: res.json,
  });
}

// 6) Admin users with anon key should fail
{
  const res = await getJson(`${functionBase}/admin/users`, {
    Authorization: `Bearer ${anonKey}`,
  });
  addResult('admin_users_requires_admin_token', res.status >= 400, {
    status: res.status,
    response: res.json,
  });
}

// 7) Admin login invalid credentials should fail
{
  const res = await postJson(`${functionBase}/admin/login`, {
    email: 'invalid@example.com',
    password: 'bad-password',
  });

  addResult('admin_login_invalid_credentials', res.status >= 400, {
    status: res.status,
    response: res.json,
  });
}

const passed = results.filter((r) => r.ok).length;
const failed = results.length - passed;

console.log(JSON.stringify({ passed, failed, results }, null, 2));

if (failed > 0) {
  process.exitCode = 1;
}
