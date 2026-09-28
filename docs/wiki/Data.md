# Data

## Usage records

Path: `~/.local/state/omarchy/agents/usage/<agent>.json`

| Writer | Agents |
|--------|--------|
| Plugin `bin/usage-update` | Prefers `bin/omarchy-agent-usage-*`, then stock `/usr/share/omarchy/bin/omarchy-agent-usage-*` |
| Plugin `bin/omarchy-agent-usage-codex` | Codex (fork with limit heal/merge) |
| `wszaq.cursor-agent` collector | Cursor (optional) |

## Heal / merge

Codex (and similar) can rewrite a usage file with an empty `limits[]` when the
app-server RPC blips. The plugin:

1. Merges new records with last-good limits in `bin/usage-update`
2. Keeps a short in-memory hold in `Usage.qml` and re-runs a targeted heal

So dials should not snap from a healthy remaining % to empty on a bad poll.

## Manual refresh

```bash
~/.config/omarchy/plugins/wszaq.token-gauge/bin/usage-update --limits-only
# or right-click the bar icon
ls ~/.local/state/omarchy/agents/usage/
```
