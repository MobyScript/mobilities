#!/usr/bin/env bash
# Opens the configured panes next to the calling herdr pane.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
[ "${HERDR_ENV:-}" = 1 ] || { echo 'Start herdr first: run "herdr" in your terminal, then start Claude Code and run /mobilities in that pane.'; exit 2; }
types=$(cfg '[.panes[]?.type] | if length>0 then .[] else empty end')
[ -n "$types" ] || types=$(gcfg '(.layout // ["ceo","todo","prs","activity"])[]')
# --ratio is the share the split pane keeps. The CEO pane gets a double share.
w() { if [ "$1" = ceo ]; then echo 2; else echo 1; fi; }
total=0; for t in $types; do total=$((total + $(w "$t"))); done
prev="${HERDR_PANE_ID:?}"; dir=right; ratio=0.5; ptype=""
for t in $types; do
  if [ -n "$ptype" ]; then
    dir=down; ratio=$(awk "BEGIN { print $(w "$ptype") / $total }"); total=$((total - $(w "$ptype")))
  fi
  new=$(herdr pane split --pane "$prev" --direction "$dir" --ratio "$ratio" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id')
  herdr pane run "$new" "$BIN/$t.sh"
  prev=$new; ptype=$t
done
echo "Opened: $(echo $types)"
