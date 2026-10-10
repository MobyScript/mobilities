#!/usr/bin/env bash
# Saves and applies named profiles: look and layout, kept in the shared config.json.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
mkdir -p "$HOMEDIR"; [ -f "$GCFG" ] || echo '{}' > "$GCFG"
look='{role, layout, panes, theme, colors, heading, fonts} | with_entries(select(.value != null))'
write() { jq "$@" "$GCFG" > "$GCFG.tmp" && mv "$GCFG.tmp" "$GCFG"; }
case "${1:-}:${2:-}" in
  save:?*)  write --arg n "$2" ".profiles[\$n] = ($look)";;
  apply:?*)
    p=$(jq -e --arg n "$2" '.profiles[$n]' "$GCFG") || { echo "No profile named $2." >&2; exit 1; }
    write --argjson p "$p" '. + ($p | del(.role, .layout, .panes))'
    mkdir -p "$(dirname "$CFG")"; [ -f "$CFG" ] || echo '{}' > "$CFG"
    jq --argjson p "$p" '. + ($p | {role, layout, panes} | with_entries(select(.value != null)))' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG";;
  list:*)   jq -r '.profiles // {} | keys[]' "$GCFG";;
  heading:*) exec "$BIN/pilot.sh" --heading "${2:-}";;
  *) echo 'Use: profile.sh save <name> | apply <name> | list | heading <off|small|big>' >&2; exit 1;;
esac
