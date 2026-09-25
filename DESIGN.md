# Design direction: Glóð (widgets and Status), B High-End (large, Lock Screen, alerts)

## Glóð

Glóð is an ember character drawn from SwiftUI shapes (`Sources/CodexResetCore/UI/GlodCharacter.swift`), shared by the app and the widget extension. Its mood comes from `GlodDerivation` and follows the widget state:

| Mood | When | Ground |
| --- | --- | --- |
| celebrating | Full-reset celebration window | `#FFC48F` → `#F07A5A` → `#B9446A`, sparkles, happy eyes |
| rich | Newest confirmed announcement added a banked credit and one is still available | `#9FE3C6` → `#3FAE9A` → `#1F6E6F`, holds a `+1` coin |
| content | Waiting, inside the typical gap | `#FFB487` → `#E8745A` → `#A8456A` |
| sleepy | Waiting longer than the typical gap (`avg_interval_days`, else the mean of cached full-reset gaps) | `#8E8CC9` → `#5C5A9C` → `#34335F`, closed eyes, `z` |
| waiting | No full reset cached | Same as content |

**Banked is the largest number** on the Glóð small and medium widgets and the second card on Status (72 pt rounded, coin jar, **Use one**).

- Small: Glóð top left, coin + banked count top right (38 pt), then the full-reset line (`10d 7h` / `since full reset`, `RESET!` / `23m ago`, `+1 banked` / `3h ago · 10d full`).
- Medium: Glóð, speech bubble and FULL block, then a banked panel (count 44 pt, up to six coins, `+1 · 3h ago` or `available`, **Use one**).
- Banked widget, small: `BANKED`, coin + count (50 pt), small Glóð, **Use one**.

**Motion.** In the app Glóð idles continuously (bob, flame sway, blink) and jumps when tapped. WidgetKit does not run continuous animation, so on widgets Glóð changes pose once per timeline entry (every minute, `GlodPose.widgetCycle`) and WidgetKit animates between entries; tapping Glóð runs `PokeGlodIntent`, which shows a jump pose and settles back. Reduce Motion stops the idle loop in the app.

The Status widget has a **Look** option (Glóð or Classic) in Edit Widget. Large and Lock Screen keep the High-End layout below.

## B High-End

Visual direction for the large widget, Lock Screen accessories, the Classic look and alerts.

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

**Medium (4×2)** is two equal columns with a hairline between them. Neither side is a footer under the other.

- Left, **FULL**: time since the last full reset (`10d 7h` / `since full`). During the celebration window the value is `RESET!` and the line under it is how long ago.
- Right, **BANKED**: the available count at the same type size. When the newest announcement added a banked credit, the line under the count is `+1 · 3h ago`, including while the left side is still celebrating a full reset.
- A scheduled reset is a caption-sized `NEXT` line under both columns. **Used banked reset** sits on that same thin line. If nothing is scheduled and the bank is empty, the line is omitted.

**Banked recent** is used on the small widget, the large widget, and the app when the newest confirmed announcement added a banked credit and the full-reset celebration window is not active. Full celebration is unchanged: it still applies only to a confirmed full reset, including combined.

- Small: `BANKED`, time since that event (`3h ago`), `10d since full`, banked count
- Large: `BANKED` with the time on the same line, `+1`, then `BANKED` / `NEXT` / `SINCE FULL` (`10d 7h`), plus the **Used banked reset** chip
- Lock Screen: `+1` in the circular accessory, `BANKED 3h · 10d full` inline

**Large** keeps the stacked card with larger type. Lock Screen accessories stay compact and monochrome (`RESET`, `10d`, banked count). They do not take the charcoal fill.

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
