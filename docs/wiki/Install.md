# Install

## From GitHub

```bash
omarchy plugin add https://github.com/wszaq/omarchy-token-gauge.git --enable
omarchy bar move wszaq.token-gauge --section right
```

Retire stock Agents from the bar (this plugin owns the usage UI):

```bash
omarchy plugin disable omarchy.agents
```

## Desktop card

In the Widgets editor (`brittiaa.widgets`), enable `wszaq.token-gauge` as a
2×2 card, or add it to `~/.config/omarchy/widgets.json`:

```json
{
  "id": "wszaq.token-gauge",
  "type": "wszaq.token-gauge",
  "enabled": true,
  "side": "right",
  "cols": 2,
  "rows": 2
}
```

## Optional Cursor records

Cursor usage JSON comes from [`wszaq.cursor-agent`](https://github.com/wszaq/omarchy-cursor-agent)
when that service plugin is enabled. Without it, Claude / Codex / Fireworks
still appear from the plugin’s `bin/usage-update` collectors.

## Uninstall

```bash
omarchy plugin disable wszaq.token-gauge
omarchy plugin remove wszaq.token-gauge --yes
```

State under `~/.local/state/omarchy/agents/usage/` is kept until you delete it.
