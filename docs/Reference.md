# Collector reference

At this review, [GitHub](https://github.com/wszaq/omarchy-token-gauge) did not mark this repository as a fork.

Use the [existing wiki](wiki/Home.md) for installation, controls, and common faults.
This page describes the collector interface and its limits.

## Refresh from a checkout

```sh
./bin/usage-update --limits-only
./bin/usage-update --force codex
./bin/usage-update --except codex
```

These examples were checked against the script. They were not executed during this review.
`--force` and `--limits-only` pass to each selected collector.
Other arguments select provider names. `--except` takes one provider name and excludes it.
See [bin/usage-update](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/bin/usage-update#L10-L32).

## Paths and dependencies

| Value | Default or behavior |
| --- | --- |
| `XDG_STATE_HOME` | Falls back to `~/.local/state`; records use `omarchy/agents/usage` below it |
| `OMARCHY_PATH` | Falls back to `/usr/share/omarchy`; stock collectors use its `bin` directory |
| Plugin collectors | Executable `bin/omarchy-agent-usage-*` files take precedence |
| `jq` | Validates collector JSON and merges previous limits |
| Record replacement | A temporary file replaces each provider JSON after collection |

See [bin/usage-update](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/bin/usage-update#L1-L8), [bin/usage-update](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/bin/usage-update#L34-L68), and [bin/usage-update](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/bin/usage-update#L70-L99).
A collector failure gives a nonzero exit status.

## Limits and display

A new empty `limits` array can retain the previous nonempty array. The merged record sets `limitsHeld` to true.
This preserves the last reading. It does not prove that a provider's quota is current.
See [bin/usage-update](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/bin/usage-update#L34-L52).

`refreshIntervalSec` defaults to 300. The manifest permits 30 through 3600 seconds, in steps of 30.
The manifest enables Claude, Codex, Cursor, and Fireworks by default.
See [manifest.json](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/manifest.json#L21-L39).
The QML model holds limits in memory for 30 minutes. See [Usage.qml](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/Usage.qml#L22-L34).

## Validate the plugin

```sh
omarchy plugin validate .
```

The repository lists this check in [AGENTS.md](https://github.com/wszaq/omarchy-token-gauge/blob/9d0805e823c81de089bc728eed176cf0b66cd0a5/AGENTS.md#L3-L10).
The reviewed snapshot has no test directory or test runner. Validation is not proof of live account accuracy.
