# Troubleshooting

## Empty panel / “No agent usage yet”

```bash
~/.config/omarchy/plugins/wszaq.token-gauge/bin/usage-update --force
ls -la ~/.local/state/omarchy/agents/usage/
```

Confirm collectors exist and CLIs are logged in (`claude`, `codex`, optional Cursor plugin).

## Codex dial snaps to empty then recovers

Expected during RPC blips; heal/merge should restore last-good limits. If it
stays empty:

```bash
~/.config/omarchy/plugins/wszaq.token-gauge/bin/omarchy-agent-usage-codex
jq '.limits' ~/.local/state/omarchy/agents/usage/codex.json
```

## Panel did not update after edit

```bash
omarchy plugin validate ~/.config/omarchy/plugins/wszaq.token-gauge
omarchy-shell shell rescanPlugins
# or
omarchy restart shell
```

## Stock Agents still on the bar

```bash
omarchy plugin disable omarchy.agents
```

This plugin is the usage UI; leave `omarchy.agents` disabled.

## Desktop card missing

Widgets use `hideWhenWindows`. Clear the workspace or open the bar popup
instead. Confirm `"enabled": true` for `wszaq.token-gauge` in
`~/.config/omarchy/widgets.json`.
