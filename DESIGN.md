# Design direction: B High-End

Approved visual direction for the widgets and alerts. The companion app stays a status and settings surface.

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| Coral | `#E8896A` | Celebration headline, full-reset notification title |
| Coral soft | `#F0A890` | Banked count on celebration, “Used banked reset” chip |
| Charcoal | `#1C1D21` → `#0C0D0F` | Home Screen widget ground |
| Mist | white at 62% | Secondary lines |
| Hairline | white at 14%, 0.5pt | Row separators and chip stroke |

Type is the system face (SF), semibold for the headline, regular for the rest. No arcade red.

Home Screen widgets use a charcoal gradient with a thin top sheen. A coral radial glow is drawn only while the widget is celebrating.

## Celebration window

Default **6 hours** after a confirmed full reset (`celebrationHours` in Settings, 1–24). A scheduled announcement never celebrates. When the window ends, the same widget switches to tracking.

## Widget layouts

**Small, celebration**

- `RESET!`
- relative time (`23m ago`)
- `2 banked`

**Small, tracking**

- two-unit elapsed (`10d 7h`)
- `since full`
- banked count

**Medium, celebration**

- `🔥 RESET!` and the relative time on one line
- `Usage limits cleared`
- hairline rows: `BANKED`, `NEXT`, `PRIOR FULL` (stamp of the full reset being celebrated)
- a capsule chip, **Used banked reset**, which runs the App Intent and does not open the app

**Medium, tracking** uses the same rows. The headline is the elapsed time, the caption is `since full reset`, and the stamp row is `LAST FULL`. Scheduled-only uses `EXPECTED` for the announced time.

**Large** repeats the medium card with larger type. Lock Screen accessories stay compact and monochrome (`RESET`, `10d`, banked count). They do not take the charcoal fill.

The gallery placeholder is the celebration layout so the add-widget sheet shows this direction.

## Notifications

Titles and bodies are the four product lines. The collapsed banner is system UI, so the coral color is on the expanded card (long-press or Notification Center), category `codex.reset`.

| Kind | Title | Body | Expanded card |
| --- | --- | --- | --- |
| Full | 🔥 Codex Full Reset | Usage limits have been reset. | Coral title, restrained glow |
| Banked | 🏦 Banked Reset Available | A reset has been added to your bank. | Charcoal, no glow |
| Double | 🔥 + 🏦 Double Reset | Usage was reset and a banked reset was added. | Charcoal, no glow |
| Scheduled | ⏳ Codex Reset Scheduled | A new reset has been announced. Expected by {Wed 23 Sep · 06:59}. | Charcoal, no glow |

Scheduled with no time omits the “Expected by” sentence.
