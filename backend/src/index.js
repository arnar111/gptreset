import { apnsConfigured, sendAlert } from "./apns.js";
import {
  allows,
  apnsPayload,
  eventsFromList,
  eventsFromStatus,
  rememberKeys,
  unseenEvents,
  withKeys,
} from "./logic.js";
import { rateLimitKeys, validInstallID, validateRegistration } from "./validate.js";

const STATUS_URL = "https://codex-resets.com/api/v1/status";
const LIST_URL = "https://codex-resets.com/api/v1/resets?limit=20&order=desc";

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(runPoll(env).catch((error) => {
      console.log(`poll failed: ${error && error.name ? error.name : "error"}`);
    }));
  },
};

export async function handleRequest(request, env, deps = {}) {
  const url = new URL(request.url);
  if (request.method === "GET" && url.pathname === "/health") {
    const state = await readState(env);
    return json({
      ok: true,
      service: "codex-reset-tracker",
      bootstrapped: Boolean(state.bootstrapped),
      apnsConfigured: apnsConfigured(env),
    });
  }

  const match = url.pathname.match(/^\/v1\/devices\/([^/]+)$/);
  if (!match) return json({ error: "not_found" }, 404);
  const installID = decodeURIComponent(match[1]);
  if (!validInstallID(installID)) return json({ error: "invalid_install_id" }, 400);

  if (request.method === "GET") {
    const record = await readDevice(env, installID);
    if (!record) return json({ registered: false });
    return json({
      registered: true,
      sandbox: record.sandbox,
      timeZone: record.timeZone,
      preferences: record.preferences,
    });
  }

  if (request.method === "DELETE") {
    await env.RESET_TRACKER.delete(deviceKey(installID));
    return json({ registered: false });
  }

  if (request.method !== "PUT") return json({ error: "method_not_allowed" }, 405);

  const limited = await tooManyRequests(request, env, deps.nowMs || Date.now());
  if (limited) return json({ error: "rate_limited" }, 429);

  const text = await request.text();
  if (text.length > 8000) return json({ error: "body_too_large" }, 413);
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const parsed = validateRegistration(body);
  if (!parsed.ok) return json({ error: parsed.error }, 400);

  const record = {
    ...parsed.value,
    updatedAt: new Date(deps.nowMs || Date.now()).toISOString(),
  };
  await env.RESET_TRACKER.put(deviceKey(installID), JSON.stringify(record));
  return json({ registered: true });
}

export async function runPoll(env, deps = {}) {
  const fetchImpl = deps.fetchImpl || fetch;
  const send = deps.sendPush || ((device, payload) => sendAlert(env, device, payload, deps));
  const nowMs = deps.nowMs || Date.now();
  const state = await readState(env);
  if (state.nextPollAt && nowMs < state.nextPollAt) {
    return { skipped: true };
  }

  const status = await fetchJSON(fetchImpl, env.CODEX_RESETS_STATUS_URL || STATUS_URL, state.statusEtag);
  if (status.rateLimited) {
    state.nextPollAt = nowMs + status.retryAfterMs;
    await writeState(env, state);
    return { rateLimited: true };
  }
  const list = await fetchJSON(fetchImpl, env.CODEX_RESETS_LIST_URL || LIST_URL, state.listEtag);
  if (list.rateLimited) {
    state.nextPollAt = nowMs + list.retryAfterMs;
    await writeState(env, state);
    return { rateLimited: true };
  }

  const collected = [];
  if (status.ok && !status.notModified) {
    const parsed = eventsFromStatus(status.body);
    if (!parsed.ok) return { error: "bad_status" };
    collected.push(...parsed.events);
    state.statusEtag = status.etag || state.statusEtag;
  }
  if (list.ok && !list.notModified) {
    const parsed = eventsFromList(list.body);
    if (!parsed.ok) return { error: "bad_list" };
    collected.push(...parsed.events);
    state.listEtag = list.etag || state.listEtag;
  }
  if (!status.ok && !list.ok) return { error: "upstream" };

  const events = dedupeEvents(withKeys(collected));
  if (!state.bootstrapped) {
    state.seen = rememberKeys([], events);
    state.bootstrapped = true;
    state.nextPollAt = 0;
    await writeState(env, state);
    return { bootstrapped: true, sent: 0 };
  }

  const fresh = unseenEvents(events, state.seen);
  if (fresh.length === 0) {
    state.nextPollAt = 0;
    await writeState(env, state);
    return { sent: 0 };
  }

  const devices = await listDevices(env);
  if (devices.length > 0 && !apnsConfigured(env) && !deps.sendPush) {
    return { waitingForAPNs: true, pending: fresh.length };
  }

  let failed = false;
  let sent = 0;
  for (const { id, record } of devices) {
    for (const event of fresh) {
      const noteKind = event.lifecycle === "scheduled" ? "scheduled" : event.kind;
      if (!allows(noteKind, record.preferences)) continue;
      const payload = apnsPayload(event, record.timeZone);
      if (!payload) continue;
      const result = await send(record, payload);
      if (result === "sent") sent += 1;
      else if (result === "unregistered") await env.RESET_TRACKER.delete(deviceKey(id));
      else failed = true;
    }
  }

  if (!failed) {
    state.seen = rememberKeys(state.seen, fresh);
    state.nextPollAt = 0;
    await writeState(env, state);
  }
  return { sent, failed, pending: fresh.length };
}

async function fetchJSON(fetchImpl, url, etag) {
  const headers = { accept: "application/json", "user-agent": "CodexResetTrackerBackend/1.0" };
  if (etag) headers["if-none-match"] = etag;
  let response;
  try {
    response = await fetchImpl(url, { headers });
  } catch {
    return { ok: false };
  }
  if (response.status === 304) return { ok: true, notModified: true, etag: response.headers.get("etag") || etag };
  if (response.status === 429) {
    const retry = Number(response.headers.get("retry-after") || "120");
    return { ok: false, rateLimited: true, retryAfterMs: (Number.isFinite(retry) ? retry : 120) * 1000 };
  }
  if (!response.ok) return { ok: false };
  try {
    const body = await response.json();
    return { ok: true, body, etag: response.headers.get("etag") };
  } catch {
    return { ok: false };
  }
}

function dedupeEvents(events) {
  const byKey = new Map();
  for (const event of events) byKey.set(event.dedupeKey, event);
  return [...byKey.values()];
}

async function readState(env) {
  const raw = await env.RESET_TRACKER.get("poll-state");
  if (!raw) return { bootstrapped: false, seen: [], nextPollAt: 0 };
  try {
    const parsed = JSON.parse(raw);
    return {
      bootstrapped: Boolean(parsed.bootstrapped),
      seen: Array.isArray(parsed.seen) ? parsed.seen : [],
      nextPollAt: Number(parsed.nextPollAt) || 0,
      statusEtag: parsed.statusEtag || "",
      listEtag: parsed.listEtag || "",
    };
  } catch {
    return { bootstrapped: false, seen: [], nextPollAt: 0 };
  }
}

async function writeState(env, state) {
  await env.RESET_TRACKER.put("poll-state", JSON.stringify(state));
}

function deviceKey(installID) {
  return `device:${installID}`;
}

async function readDevice(env, installID) {
  const raw = await env.RESET_TRACKER.get(deviceKey(installID));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function listDevices(env) {
  const listed = await env.RESET_TRACKER.list({ prefix: "device:" });
  const devices = [];
  for (const key of listed.keys || []) {
    const raw = await env.RESET_TRACKER.get(key.name);
    if (!raw) continue;
    try {
      devices.push({ id: key.name.slice("device:".length), record: JSON.parse(raw) });
    } catch {
      // Ignore a corrupt device row rather than failing the poll.
    }
  }
  return devices;
}

async function tooManyRequests(request, env, nowMs) {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const key = rateLimitKeys(ip, nowMs);
  const count = Number(await env.RESET_TRACKER.get(key) || "0") + 1;
  await env.RESET_TRACKER.put(key, String(count), { expirationTtl: 7200 });
  return count > 30;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
