import assert from "node:assert/strict";
import test from "node:test";
import { memoryKV } from "./memory-kv.js";
import { handleRequest, runPoll } from "../src/index.js";
import {
  dedupeKey,
  eventsFromList,
  eventsFromStatus,
  notificationFor,
  unseenEvents,
} from "../src/logic.js";
import { validateRegistration } from "../src/validate.js";

const full = {
  id: "full-old",
  reset_type: "regular",
  announced_at: "2026-09-12T08:09:17.000Z",
  text: "Reset all propagated.",
  source: { type: "x_post", author: "thsottiaux", url: "https://x.com/thsottiaux/status/full-old" },
};

const scheduled = {
  id: "sched-1",
  status: "scheduled",
  reset_type: "regular",
  announced_at: "2026-09-22T04:31:32.000Z",
  scheduled_for: "2026-09-23T06:59:00.000Z",
  text: "Tuesday.",
  source: { type: "x_post", author: "thsottiaux", url: "https://x.com/thsottiaux/status/sched-1" },
};

test("live-shaped status keeps scheduled separate from a completed full reset", () => {
  const parsed = eventsFromStatus({
    data: { latest_reset: full, scheduled_reset: scheduled, active_watch: null, stats: { total: 53 } },
    meta: { api_version: "v1" },
  });
  assert.equal(parsed.ok, true);
  const latest = parsed.events.find((event) => event.id === "full-old");
  const pending = parsed.events.find((event) => event.id === "sched-1");
  assert.equal(latest.lifecycle, "confirmed");
  assert.equal(latest.kind, "full");
  assert.equal(pending.lifecycle, "scheduled");
  assert.notEqual(dedupeKey(latest), dedupeKey(pending));
  assert.equal(notificationFor(pending, "UTC").title, "⏳ Codex Reset Scheduled");
  assert.match(notificationFor(pending, "UTC").body, /Wed 23 Sep · 06:59/);
  assert.equal(notificationFor(latest, "UTC").title, "🔥 Codex Full Reset");
});

test("malformed rows are skipped and an unknown type does not notify", () => {
  const parsed = eventsFromList({
    data: [
      full,
      "nope",
      { reset_type: "banked", text: "missing date" },
      { id: "mystery", reset_type: "surprise", announced_at: "2026-09-22T12:00:00.000Z", text: "?" },
      {
        id: "bank-1",
        reset_type: "banked",
        announced_at: "2026-09-22T12:00:00.000Z",
        text: "Banked.",
        extra: true,
      },
    ],
  });
  assert.equal(parsed.ok, true);
  assert.deepEqual(parsed.events.map((event) => event.id), ["full-old", "mystery", "bank-1"]);
  const fresh = unseenEvents(parsed.events.map((event) => ({ ...event, dedupeKey: dedupeKey(event) })), []);
  assert.deepEqual(fresh.map((event) => event.kind).sort(), ["banked", "full"]);
});

test("combined announcement produces one notification", () => {
  const event = eventsFromList({
    data: [{
      id: "both",
      reset_type: "combined",
      announced_at: "2026-09-22T12:00:00.000Z",
      text: "Both",
    }],
  }).events[0];
  const note = notificationFor(event, "UTC");
  assert.equal(note.kind, "combined");
  assert.equal(note.title, "🔥 + 🏦 Double Reset");
});

test("first poll bootstraps without sending, later polls notify once", async () => {
  const kv = memoryKV();
  const env = { RESET_TRACKER: kv };
  const sent = [];
  let phase = "initial";
  const fetchImpl = async (url) => {
    const status = phase === "initial"
      ? { data: { latest_reset: full, scheduled_reset: scheduled } }
      : {
          data: {
            latest_reset: {
              id: "full-new",
              reset_type: "regular",
              announced_at: "2026-09-22T15:00:00.000Z",
              text: "Reset all propagated.",
            },
            scheduled_reset: null,
          },
        };
    const list = phase === "initial"
      ? { data: [full] }
      : { data: [full, status.data.latest_reset] };
    const body = url.includes("/status") ? status : list;
    return new Response(JSON.stringify(body), { status: 200, headers: { etag: phase } });
  };

  const first = await runPoll(env, { fetchImpl, sendPush: async () => sent.push("nope") });
  assert.equal(first.bootstrapped, true);
  assert.equal(first.sent, 0);
  assert.equal(sent.length, 0);

  await handleRequest(new Request("https://worker.test/v1/devices/11111111-1111-4111-8111-111111111111", {
    method: "PUT",
    body: JSON.stringify({
      apnsToken: "ab".repeat(32),
      sandbox: true,
      timeZone: "UTC",
      preferences: { full: true, banked: true, scheduled: true },
    }),
  }), env);

  phase = "landed";
  const second = await runPoll(env, {
    fetchImpl,
    sendPush: async (_device, payload) => {
      sent.push(payload);
      return "sent";
    },
  });
  assert.equal(second.sent, 1);
  assert.equal(sent[0].kind, "full");
  assert.equal(sent[0].aps.alert.title, "🔥 Codex Full Reset");

  const third = await runPoll(env, {
    fetchImpl,
    sendPush: async () => {
      sent.push("duplicate");
      return "sent";
    },
  });
  assert.equal(third.sent, 0);
  assert.equal(sent.length, 1);
});

test("same banked event is only pushed once", async () => {
  const kv = memoryKV();
  const env = { RESET_TRACKER: kv };
  const banked = {
    id: "bank-1",
    reset_type: "banked",
    announced_at: "2026-09-22T12:00:00.000Z",
    text: "Banked.",
  };
  let includeBanked = false;
  const fetchImpl = async (url) => {
    const latest = includeBanked ? banked : full;
    const body = url.includes("/status")
      ? { data: { latest_reset: latest, scheduled_reset: null } }
      : { data: includeBanked ? [full, banked] : [full] };
    return new Response(JSON.stringify(body), { status: 200 });
  };
  await runPoll(env, { fetchImpl, sendPush: async () => "sent" });
  await handleRequest(new Request("https://worker.test/v1/devices/11111111-1111-4111-8111-111111111111", {
    method: "PUT",
    body: JSON.stringify({ apnsToken: "cd".repeat(32), sandbox: false, timeZone: "UTC", preferences: { full: true, banked: true, scheduled: false } }),
  }), env);
  includeBanked = true;
  const pushes = [];
  for (let index = 0; index < 5; index += 1) {
    await runPoll(env, {
      fetchImpl,
      sendPush: async (_device, payload) => {
        pushes.push(payload.kind);
        return "sent";
      },
    });
  }
  assert.deepEqual(pushes, ["banked"]);
});

test("scheduled preference can suppress the scheduled alert without marking a full reset", async () => {
  const kv = memoryKV();
  const env = { RESET_TRACKER: kv };
  const fetchImpl = async (url) => {
    const body = url.includes("/status")
      ? { data: { latest_reset: full, scheduled_reset: null } }
      : { data: [full] };
    return new Response(JSON.stringify(body), { status: 200 });
  };
  await runPoll(env, { fetchImpl });
  await handleRequest(new Request("https://worker.test/v1/devices/11111111-1111-4111-8111-111111111111", {
    method: "PUT",
    body: JSON.stringify({
      apnsToken: "ef".repeat(32),
      sandbox: true,
      timeZone: "UTC",
      preferences: { full: true, banked: true, scheduled: false },
    }),
  }), env);
  const pushes = [];
  const withSchedule = async (url) => {
    const body = url.includes("/status")
      ? { data: { latest_reset: full, scheduled_reset: scheduled } }
      : { data: [full] };
    return new Response(JSON.stringify(body), { status: 200 });
  };
  const result = await runPoll(env, {
    fetchImpl: withSchedule,
    sendPush: async (_device, payload) => {
      pushes.push(payload.kind);
      return "sent";
    },
  });
  assert.equal(result.sent, 0);
  assert.deepEqual(pushes, []);
});

test("429 backs off and a bad payload does not bootstrap", async () => {
  const kv = memoryKV();
  const env = { RESET_TRACKER: kv };
  const limited = await runPoll(env, {
    nowMs: 1_000,
    fetchImpl: async () => new Response("busy", { status: 429, headers: { "retry-after": "30" } }),
  });
  assert.equal(limited.rateLimited, true);
  const skipped = await runPoll(env, { nowMs: 2_000, fetchImpl: async () => { throw new Error("should not fetch"); } });
  assert.equal(skipped.skipped, true);

  const bad = await runPoll({ RESET_TRACKER: memoryKV() }, {
    fetchImpl: async () => new Response("not-json", { status: 200, headers: { "content-type": "text/plain" } }),
  });
  assert.equal(bad.error, "upstream");
});

test("registration rejects bad tokens and does not echo them", async () => {
  const env = { RESET_TRACKER: memoryKV() };
  const bad = await handleRequest(new Request("https://worker.test/v1/devices/11111111-1111-4111-8111-111111111111", {
    method: "PUT",
    body: JSON.stringify({ apnsToken: "nope", sandbox: true }),
  }), env);
  assert.equal(bad.status, 400);
  const install = "11111111-1111-4111-8111-111111111111";
  const token = "aa".repeat(32);
  const ok = await handleRequest(new Request(`https://worker.test/v1/devices/${install}`, {
    method: "PUT",
    body: JSON.stringify({ apnsToken: token, sandbox: true, timeZone: "Atlantic/Reykjavik", preferences: { full: false, banked: true, scheduled: true } }),
  }), env);
  assert.equal(ok.status, 200);
  const stored = JSON.parse(await env.RESET_TRACKER.get(`device:${install}`));
  assert.equal(stored.preferences.full, false);
  const view = await handleRequest(new Request(`https://worker.test/v1/devices/${install}`), env);
  const body = await view.json();
  assert.equal(body.registered, true);
  assert.equal(body.token, undefined);
  assert.equal(validateRegistration({ apnsToken: token, sandbox: false }).ok, true);
});

test("health stays free of secrets", async () => {
  const response = await handleRequest(new Request("https://worker.test/health"), {
    RESET_TRACKER: memoryKV(),
    APNS_PRIVATE_KEY: "secret",
  });
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(JSON.stringify(body).includes("secret"), false);
});
