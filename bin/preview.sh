#!/usr/bin/env bash
# Opens the configured layout with an agent in a new tab.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
host=$(pane_host) || exit 2
agent=$(agent_cmd)
if [ "$host" = herdr ]; then
  tab=$(herdr tab create --label 'mobilities preview' --cwd "$ROOT" --focus)
  root=$(jq -r '.result.root_pane.pane_id' <<<"$tab")
  herdr pane run "$root" "$agent" >/dev/null
  HERDR_PANE_ID="$root" "$BIN/open.sh" >/dev/null
  echo "Close with: herdr tab close $(jq -r '.result.tab.tab_id' <<<"$tab")"
else
  h=$(orca terminal create --title 'mobilities preview' --command "cd '$ROOT' && $agent" --focus --json | jq -r '.result.terminal.handle')
  ORCA_TERMINAL_HANDLE="$h" "$BIN/open.sh" >/dev/null
  orca terminal rename --terminal "$h" --title 'mobilities preview' >/dev/null
  echo "Close with: orca terminal close --terminal $h --tab"
fi
