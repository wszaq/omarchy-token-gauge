# Controls

## Bar / desktop

| Input | Action |
|-------|--------|
| Left click (bar) | Toggle the popup panel |
| Right click | Force a usage refresh |
| Middle click | Launch the agent picker |

The desktop card shows the same panel content while the Widgets surface is
visible (`hideWhenWindows` may hide it when apps cover the desktop).

## Per provider

| Slot | Meaning |
|------|---------|
| Dial + center `%` | Remaining on the hottest usage limit |
| `N% left` + `↻` | Remaining and reset countdown for that limit |
| Meta line | Tier · limit label · tokens today (provider’s own names) |
| Secondary meters | Other limits as remaining % |
| Money line | Shown only when prepaid `funded > 0` |

## Shared footer

**Today · 7d · Avg/d · sparkline** — token totals across tracked providers.
No dollar KPIs in this strip.
