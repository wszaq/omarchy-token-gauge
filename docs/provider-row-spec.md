# Provider row spec

Use one compact section per provider. Keep the Cursor dial and field positions.
Follow the Hardware Tooltip's section rhythm. Do not add a provider hero block.

## Wireframe

```
┌──────────────────────────────────────────────────────────┐
│  (dial 2%) Cursor                      2% left           │
│            Pro · API · 306.8M tokens today ↻ 14d         │
│                                                          │
│            Included  ████████░░  13% left · ↻ 14d 11h    │
│            Auto      ████████░░  14% left · ↻ 14d 11h    │
│            $430.63 spent · $20 funded · $0 left           │
└──────────────────────────────────────────────────────────┘
```

Use this layout for Claude, Codex, Cursor, Fireworks, and future agents.
Align secondary meters with the provider name. Use `Style.space(14)` between
sections and `Style.space(6)` inside each section. Use a thin separator.

Use `Style.font.title` for the name and the dial center value. Use `bodySmall`
for metadata and `caption` for reset / secondary limits. Use the bar font
family and `Qt.darker(fg, 1.4)` for dim captions.

## Fuel tank (remaining)

Dial fill, big `%`, secondary meter fills, and meter labels show **remaining**:

`remaining = max(0, 1 - used)`

Over-limit used → 0% left. Primary limit is still picked by **hottest used**
(emptiest tank). Balance never drives the dial.

## Primary KPIs (every provider)

| Slot | Source | Rule |
|---|---|---|
| Dial center % | Remaining on highest-used **usage limit** | Show `remaining` percent in the dial hollow (JustGage). A balance does not replace a limit. |
| Reset | That limit's `resetsAt` | Right column: `left` + `↻ Nd Nh`. Hide timer for an invalid date; still show `left` when a limit exists. |
| Title | `name` | Fallback `id`. |
| Meta line | `tierLabel` · limit label · today tokens | Use each provider's own labels (e.g. Cursor `Pro · API models · …`, Claude `Max 5x · Weekly (7-day) · …`). |
| Secondary meters | Other valid limits | Remaining % under the collector's own label. Do not rename into a shared vocabulary. |
| Money line | `balance` | If valid and `funded > 0`, show spent, funded, and remaining. Add `est.` when estimated. |

### Primary limit pick

1. Ignore limits without a valid numeric percent. Normalize values above 1 as
   percentages. Clamp each **used** value to 0–100% for ranking.
2. Pick the highest used percent. If values tie, choose the soonest valid
   future reset. If those tie, keep source order.
3. Keep qualifiers in labels such as `Fable Weekly`. Exclude the chosen limit
   from secondary meters by source index, not by label.
4.   If there is no valid limit, show a dim dial with no fill and `—` in its
   center. Keep the tier and today's tokens. Show `Limits unavailable` as a
   short status. Do not show a reset timer.

Show today's token count even when it is zero. Use a compact count, then
`tokens today`. Do not replace it with a lifetime count. Update valid reset
timers while the popup or desktop card is visible.

## Dial look

Match the JustGage / Dribbble 2185155 language as far as QML Canvas allows:

- 180° semicircle, filled annular band (radial ends, not round-cap stroke)
- Soft outer tick marks (major every 25%)
- One solid progress sector for remaining (no rainbow)
- Tip needle that crosses the band (JustGage `ndl`, not a hub needle)
- Large remaining `%` in the dial hollow; E / F under the band ends
- Stronger dim track contrast; OutCubic animation (~700 ms)

Keep the per-provider row layout (no aggregate gauge, no hero dial).

## Solid color bands (remaining)

Use one solid color for the filled arc, the large value, and each secondary
meter fill. Do not paint a rainbow along the arc.

| Band | Remaining | Color |
|---|---|---|
| Green | >75% | `Color.accent` |
| White | >50–75% | `Color.foreground` |
| Yellow | >25–50% | `#E8BB59` |
| Orange | >10–25% | `#E5A77E` |
| Red | ≤10% or empty | `#FF4D4D` |

## Visibility

Show a provider when it has a valid limit, positive today tokens, a valid
funded balance, or `ready === true`.

Hide it only if `ready === false`, there are no valid limits, today's tokens
are zero, and there is no valid funded balance. This hides empty Fireworks.
If no provider qualifies, show one dim line: `No agent usage yet`.

For a valid prepaid balance, show a money caption below the limits. A balance
never drives the dial. Do not compute `spent/funded` as a usage percent:
Cursor has spent $430.63 against $20 funded. Show the actual money amounts.

## Do not show

- Prompt and session counts, lifetime totals, and model breakdown.
- Raw dates, long status messages, authentication help, and rotating phrases.
- A second large dial for another limit or for money.
- A rainbow arc, color interpolation, or a reset marker without a valid date.
- Forced shared limit names (Included / Auto / API).

Truncate long names and captions so the row stays easy to read.

## Shared bottom strip

One lean row under all provider sections (thin separator above). Bold values,
dim captions. Panel ~420px — keep compact. No Cursor $ spent.

| Slot | Source | Rule |
|---|---|---|
| Today | Σ `todayTotalTokens` | Sum across tracked (visible) providers. |
| 7d | Σ `recentDays` | Align by `date`. `messageCount` is daily tokens (legacy name). Missing provider-day → skip that provider for that day; do not invent zeros. Take the last ≤7 dates present in the union. |
| Avg/d | 7d ÷ 7 | Always divide by 7, even if fewer dates contributed. |
| Sparkline | same series | Small Canvas (~60–80px), single stroke + soft fill, accent/fg language. Tiny `7d` caption only. |

Keep fuel-tank dials and per-provider rows unchanged. Do not add an aggregate
gauge or a money aggregate.
