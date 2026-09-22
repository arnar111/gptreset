/**
 * Reset classification and dedupe keys shared with the iOS app.
 * Confirmed key: `${id}|confirmed|${kind}`
 * Scheduled key: `${id}|scheduled|${kind}|${scheduledForMillis}`
 * A passed scheduled_for does not mean the reset completed.
 */

const FULL_TYPES = new Set(["regular", "full", "standard"]);
const BANKED_TYPES = new Set(["banked", "bank"]);
const COMBINED_TYPES = new Set(["combined", "both", "full_banked", "full+banked", "regular_and_banked"]);

export function mapKind(resetType, flags = {}) {
  if (flags.isFullReset != null || flags.addsBankedReset != null) {
    const full = flags.isFullReset === true;
    const banked = flags.addsBankedReset === true;
    if (full && banked) return "combined";
    if (full) return "full";
    if (banked) return "banked";
    return "unclassified";
  }
  const value = String(resetType || "").trim().toLowerCase();
  if (FULL_TYPES.has(value)) return "full";
  if (BANKED_TYPES.has(value)) return "banked";
  if (COMBINED_TYPES.has(value)) return "combined";
  return "unclassified";
}

export function dedupeKey(event) {
  if (event.lifecycle === "scheduled") {
    const millis = event.scheduledFor ? String(Math.round(Date.parse(event.scheduledFor))) : "";
    return `${event.id}|scheduled|${event.kind}|${millis}`;
  }
  return `${event.id}|confirmed|${event.kind}`;
}

export function normalizeAnnouncement(row, forcedLifecycle) {
  if (!row || typeof row !== "object") return null;
  const announcedAt = row.announced_at;
  if (typeof announcedAt !== "string" || Number.isNaN(Date.parse(announcedAt))) return null;
  const kind = mapKind(row.reset_type, {
    isFullReset: row.is_full_reset,
    addsBankedReset: row.adds_banked_reset,
  });
  const lifecycle = forcedLifecycle === "scheduled" || row.status === "scheduled" ? "scheduled" : "confirmed";
  const upstreamID = typeof row.id === "string" ? row.id.trim() : "";
  const sourceURL = row.source && typeof row.source.url === "string" ? row.source.url : "";
  const text = typeof row.text === "string" ? row.text : "";
  const id = upstreamID || fingerprint(kind, announcedAt, text, sourceURL);
  return {
    id,
    kind,
    lifecycle,
    announcedAt,
    scheduledFor: lifecycle === "scheduled" && typeof row.scheduled_for === "string" ? row.scheduled_for : null,
    text,
    sourceURL,
  };
}

export function fingerprint(kind, announcedAt, text, sourceURL) {
  const millis = Math.round(Date.parse(announcedAt));
  const canonical = ["v1", kind, String(millis), text || "", sourceURL || ""].join("|");
  return `fp_${fnv1a(canonical)}`;
}

export function eventsFromStatus(body) {
  if (!body || typeof body !== "object" || !body.data || typeof body.data !== "object") {
    return { ok: false, events: [] };
  }
  const events = [];
  const latest = normalizeAnnouncement(body.data.latest_reset, "confirmed");
  if (latest) events.push(latest);
  const scheduled = normalizeAnnouncement(body.data.scheduled_reset, "scheduled");
  if (scheduled) events.push(scheduled);
  return { ok: true, events };
}

export function eventsFromList(body) {
  if (!body || typeof body !== "object" || !Array.isArray(body.data)) {
    return { ok: false, events: [] };
  }
  const events = [];
  for (const row of body.data) {
    const event = normalizeAnnouncement(row, "confirmed");
    if (event) events.push(event);
  }
  return { ok: true, events };
}

export function withKeys(events) {
  return events.map((event) => ({ ...event, dedupeKey: dedupeKey(event) }));
}

export function notificationKind(event) {
  if (event.lifecycle === "scheduled") return "scheduled";
  if (event.kind === "full" || event.kind === "banked" || event.kind === "combined") return event.kind;
  return null;
}

export function allows(kind, preferences) {
  const prefs = preferences || { full: true, banked: true, scheduled: true };
  if (kind === "full") return prefs.full !== false;
  if (kind === "banked") return prefs.banked !== false;
  if (kind === "scheduled") return prefs.scheduled !== false;
  if (kind === "combined") return prefs.full !== false || prefs.banked !== false;
  return false;
}

export function formatStamp(iso, timeZone) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const zone = timeZone || "UTC";
  const weekday = part(date, zone, { weekday: "short" });
  const day = part(date, zone, { day: "numeric" });
  const month = part(date, zone, { month: "short" });
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).format(date);
  return `${weekday} ${day} ${month} · ${time}`;
}

export function notificationFor(event, timeZone) {
  const kind = notificationKind(event);
  if (!kind) return null;
  if (kind === "full") {
    return { kind, title: "🔥 Codex Full Reset", body: "Usage limits have been reset." };
  }
  if (kind === "banked") {
    return { kind, title: "🏦 Banked Reset Available", body: "A reset has been added to your bank." };
  }
  if (kind === "combined") {
    return { kind, title: "🔥 + 🏦 Double Reset", body: "Usage was reset and a banked reset was added." };
  }
  const when = event.scheduledFor ? formatStamp(event.scheduledFor, timeZone) : "";
  const body = when
    ? `A new reset has been announced. Expected by ${when}.`
    : "A new reset has been announced.";
  return { kind, title: "⏳ Codex Reset Scheduled", body };
}

export function unseenEvents(events, seenKeys) {
  const seen = new Set(seenKeys || []);
  return events.filter((event) => {
    const kind = notificationKind(event);
    return kind && !seen.has(event.dedupeKey || dedupeKey(event));
  });
}

export function rememberKeys(existing, events, limit = 1000) {
  const next = [...(existing || [])];
  const known = new Set(next);
  for (const event of events) {
    const key = event.dedupeKey || dedupeKey(event);
    if (!known.has(key)) {
      known.add(key);
      next.push(key);
    }
  }
  if (next.length > limit) return next.slice(next.length - limit);
  return next;
}

export function apnsPayload(event, timeZone) {
  const note = notificationFor(event, timeZone);
  if (!note) return null;
  const key = event.dedupeKey || dedupeKey(event);
  return {
    aps: {
      alert: { title: note.title, body: note.body },
      sound: "default",
      "thread-id": note.kind,
    },
    eventId: event.id,
    dedupeKey: key,
    kind: note.kind,
    link: `codexreset://event/${encodeURIComponent(event.id)}`,
  };
}

function part(date, timeZone, options) {
  return new Intl.DateTimeFormat("en-US", { timeZone, ...options }).format(date);
}

function fnv1a(text) {
  let hash = 0xcbf29ce484222325n;
  const prime = 0x100000001b3n;
  const bytes = new TextEncoder().encode(text);
  for (const byte of bytes) {
    hash ^= BigInt(byte);
    hash = (hash * prime) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, "0");
}
