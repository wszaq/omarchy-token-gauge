# AGENTS.md — wszaq.token-gauge

## First commands

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint TokenGauge.qml Usage.qml Agent.qml || true
ls ~/.local/state/omarchy/agents/usage/
omarchy-agent-usage-update --limits-only
```

## Where to change what

| Symptom | File |
|---|---|
| Wrong providers / refresh / token formatting | `Usage.qml` |
| File watch / parse | `Agent.qml` |
| Gauges, timers, phrases, colors, layout | `TokenGauge.qml` |
| Defaults / schema | `manifest.json` |

## Desktop card

`brittiaa.widgets` embeds via `open()` / `desktopEmbedded` (same as
Hardware Tooltip). After layout changes, enable a 2×2 or 2×3 card in
`~/.config/omarchy/widgets.json` and confirm gauges are not clipped.

## Trust boundary

Unsandboxed inside `omarchy-shell`. May only spawn
`omarchy-agent-usage-update` and the optional cursor collector path via
`Process` argument arrays. No shell strings.
