# Agent Tokens (`wszaq.token-gauge`)

Omarchy **bar-widget** (and optional desktop card) for AI agent token **remaining**
on this machine. Per-provider fuel-tank dials replace the stock `omarchy.agents`
usage UI on the bar.

<p align="center">
  <img src="assets/screenshot-panel.png" alt="Agent Tokens panel with remaining % dials and Today / 7d / Avg/d footer" width="420">
</p>

More: [desktop context](assets/screenshot-desktop-context.png).

Full guide: **[Wiki](docs/wiki/Home.md)** (Install, Controls, Data, Screenshots, Troubleshooting).

## Install

```bash
omarchy plugin add https://github.com/wszaq/omarchy-token-gauge.git --enable
omarchy bar move wszaq.token-gauge --section right
```

Disable stock Agents on the bar (this plugin owns the usage UI):

```bash
omarchy plugin disable omarchy.agents
```

Optional desktop card: Widgets editor, or a `wszaq.token-gauge` entry in
`~/.config/omarchy/widgets.json` (`"cols": 2`, `"rows": 2`, `"enabled": true`).

### Local sync (development)

Omarchy rejects symlinks under `plugins/`. Rsync a real copy:

```bash
rsync -a --delete --exclude tmp --exclude .git --exclude assets/_capture\* \
  ~/Work/_WAJBKODING/repos/wszaq-token-gauge/ \
  ~/.config/omarchy/plugins/wszaq.token-gauge/
omarchy plugin validate ~/.config/omarchy/plugins/wszaq.token-gauge
omarchy-shell shell rescanPlugins
```

## What you see

Same row for every provider (see [`docs/provider-row-spec.md`](docs/provider-row-spec.md)):

```
(dial)  Name                              12% left
        Tier · Limit · 307M tokens today  ↻ 14d 11h
        Session  ████  88% left · ↻ …
        $430 spent · $20 funded · $0 left   ← only when funded > 0
```

| Element | Rule |
|---|---|
| **Dial + %** | **Remaining** on the hottest usage limit (emptiest tank). Balance never drives the dial. |
| **Reset** | Countdown for that limit (`↻ …`) |
| **Meta** | Provider’s own tier · limit label · tokens today |
| **Secondaries** | Other limits as remaining %, under their own names |
| **Money** | Prepaid line when `funded > 0` (provider row only — not in the shared footer) |
| **No limit** | Dim dial, `—`, and `Limits unavailable` |

### Shared footer

One strip under all providers (no Cursor $ here):

| Slot | Source |
|---|---|
| **Today** | Σ `todayTotalTokens` across tracked providers |
| **7d** | Σ daily token series from `recentDays` (aligned by date) |
| **Avg/d** | 7d ÷ 7 |
| sparkline | same 7d series |

`recentDays[].messageCount` is the day’s **token** total (legacy field name).
Missing provider-days are skipped — no invented zeros.

### Dial look

JustGage / [Dribbble 2185155](https://dribbble.com/shots/2185155-Animated-gauges)
language in QML `Canvas`: filled annular 180° band, soft ticks, solid remaining
sector, tip needle, center `%`, E/F under the ends. No rainbow arc.

| Remaining | Color |
|---|---|
| >75% | green (accent) |
| >50–75% | white (foreground) |
| >25–50% | yellow `#E8BB59` |
| >10–25% | orange `#E5A77E` |
| ≤10% or empty | vibrant red `#FF4D4D` |

## Interactions

| Input | Action |
|---|---|
| Left click | Toggle panel |
| Right click | Force usage refresh |
| Middle click | Launch agent picker |

## Data sources

Reads `~/.local/state/omarchy/agents/usage/*.json`:

| Writer | Records |
|---|---|
| Plugin `bin/usage-update` (prefers plugin collectors, then stock Omarchy) | claude, codex, fireworks, … |
| Plugin `bin/omarchy-agent-usage-codex` | codex (fork; heals flaky RPC limits) |
| `wszaq.cursor-agent` (optional) | cursor |

Blank `limits[]` rewrites are merged with the last good limits so dials do not
snap empty on a bad Codex poll.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `refreshIntervalSec` | `300` | Collector refresh interval |

## Uninstall

```bash
omarchy plugin disable wszaq.token-gauge
omarchy plugin remove wszaq.token-gauge --yes
```

Usage JSON under `~/.local/state/omarchy/agents/usage/` is left in place.

## Design

- Typography / spacing: Hardware Tooltip (`im0001gt.hw-tooltip`)
- Row contract: `docs/provider-row-spec.md`
- License: MIT · Author: **wszaq**
