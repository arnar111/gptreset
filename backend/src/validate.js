const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TOKEN_PATTERN = /^[0-9a-f]{64,200}$/i;

export function validateRegistration(body) {
  if (!body || typeof body !== "object") {
    return { ok: false, error: "invalid_body" };
  }
  if (typeof body.apnsToken !== "string" || !TOKEN_PATTERN.test(body.apnsToken)) {
    return { ok: false, error: "invalid_token" };
  }
  if (typeof body.sandbox !== "boolean") {
    return { ok: false, error: "invalid_sandbox" };
  }
  const timeZone = typeof body.timeZone === "string" && body.timeZone.length <= 80
    ? body.timeZone
    : "UTC";
  const preferences = body.preferences && typeof body.preferences === "object" ? body.preferences : {};
  return {
    ok: true,
    value: {
      token: body.apnsToken.toLowerCase(),
      sandbox: body.sandbox,
      timeZone,
      preferences: {
        full: preferences.full !== false,
        banked: preferences.banked !== false,
        scheduled: preferences.scheduled !== false,
      },
    },
  };
}

export function validInstallID(value) {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

export function rateLimitKeys(ip, nowMs) {
  const hour = Math.floor(nowMs / 3_600_000);
  const safeIP = String(ip || "unknown").slice(0, 80);
  return `rl:${safeIP}:${hour}`;
}
