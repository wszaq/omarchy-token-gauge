#!/usr/bin/env bash
# Capture live screenshots for README/wiki. Run on an unlocked Omarchy desktop
# with the token-gauge panel or desktop card visible (hide covering windows;
# Widgets use hideWhenWindows).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets"
mkdir -p "$OUT"

stamp="$(date +%Y%m%d-%H%M%S)"
panel="$OUT/screenshot-panel.png"
desktop="$OUT/screenshot-desktop.png"
context="$OUT/screenshot-desktop-context.png"

echo "Select the Agent Tokens panel / card region…"
grim -g "$(slurp)" "$panel"
cp -f "$panel" "$desktop"
echo "Wrote $panel (and $desktop)"

echo "Select a wider desktop-context region (or Esc to skip)…"
if geom="$(slurp 2>/dev/null)"; then
  grim -g "$geom" "$context"
  echo "Wrote $context"
else
  echo "Skipped desktop-context capture"
fi

cp -f "$panel" "$OUT/screenshot-panel-$stamp.png" 2>/dev/null || true
ls -la "$OUT"/screenshot-*.png 2>/dev/null || true
