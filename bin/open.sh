#!/usr/bin/env bash
# Opens the configured panes next to the calling herdr pane.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
[ "${HERDR_ENV:-}" = 1 ] || { echo 'Start herdr first: run "herdr" in your terminal, then start Claude Code and run /mobilities in that pane.'; exit 2; }
types=$(cfg '[.panes[]?.type] | if length>0 then .[] else empty end')
[ -n "$types" ] || types=$(gcfg '(.layout // ["ceo","todo","prs","activity"])[]')
prev="${HERDR_PANE_ID:?}"; dir=right
for t in $types; do
  new=$(herdr pane split --pane "$prev" --direction "$dir" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id // .result.pane.id // .result.pane')
  herdr pane run "$new" "$BIN/$t.sh"
  prev=$new; dir=down
done
echo "Opened: $(echo $types)"
