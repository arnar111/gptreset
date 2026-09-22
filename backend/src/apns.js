const JWT_LIFETIME_SECONDS = 50 * 60;

let cachedJWT = null;

export function pemToBytes(pem) {
  const body = String(pem)
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export function bytesToBase64URL(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

export function base64URLToBytes(value) {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") + "===".slice((value.length + 3) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export async function buildAPNsJWT({ teamId, keyId, privateKeyPem, nowSeconds }) {
  const header = bytesToBase64URL(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = bytesToBase64URL(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: nowSeconds })));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  ));
  return `${signingInput}.${bytesToBase64URL(signature)}`;
}

export function apnsConfigured(env) {
  return Boolean(env.APNS_KEY_ID && env.APNS_TEAM_ID && env.APNS_BUNDLE_ID && env.APNS_PRIVATE_KEY);
}

export async function authorizationHeader(env, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (cachedJWT && cachedJWT.keyId === env.APNS_KEY_ID && cachedJWT.exp - 60 > nowSeconds) {
    return cachedJWT.token;
  }
  const token = await buildAPNsJWT({
    teamId: env.APNS_TEAM_ID,
    keyId: env.APNS_KEY_ID,
    privateKeyPem: env.APNS_PRIVATE_KEY,
    nowSeconds,
  });
  cachedJWT = { token, keyId: env.APNS_KEY_ID, exp: nowSeconds + JWT_LIFETIME_SECONDS };
  return token;
}

export function resetAPNsCache() {
  cachedJWT = null;
}

/**
 * Sends one alert. Returns "sent", "unregistered", "not_configured", or "failed".
 * The device token is never written to logs.
 */
export async function sendAlert(env, device, payload, deps = {}) {
  if (!apnsConfigured(env)) return "not_configured";
  const fetchImpl = deps.fetchImpl || fetch;
  const nowSeconds = deps.nowSeconds || Math.floor(Date.now() / 1000);
  let jwt;
  try {
    jwt = await authorizationHeader(env, nowSeconds);
  } catch (error) {
    console.log(`apns jwt failed: ${error && error.name ? error.name : "error"}`);
    return "failed";
  }
  const host = device.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const collapse = String(payload.dedupeKey || "reset").slice(0, 64);
  let response;
  try {
    response = await fetchImpl(`https://${host}/3/device/${device.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": env.APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-collapse-id": collapse,
      },
      body: JSON.stringify(payload),
    });
  } catch (error) {
    console.log(`apns send failed: ${error && error.name ? error.name : "error"}`);
    return "failed";
  }
  if (response.status === 200) return "sent";
  if (response.status === 410 || response.status === 400) return "unregistered";
  console.log(`apns status ${response.status}`);
  return "failed";
}
