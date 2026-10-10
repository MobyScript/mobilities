#!/usr/bin/env bash
# Opens a new tab with one live Pilot pane per style: preview.sh fonts|themes
set -euo pipefail
. "$(dirname "$0")/lib.sh"
host=$(pane_host) || exit 2
case "${1:-}" in
  fonts)  var=MOBILITIES_HEADING; opts=(off small big);;
  themes) var=MOBILITIES_THEME;   opts=(default dark light ocean sunset mono);;
  *) echo 'Use: preview.sh fonts|themes' >&2; exit 1;;
esac
cmds=(); for o in "${opts[@]}"; do cmds+=("cd '$ROOT' && MOBILITIES_PREVIEW='$o' $var=$o '$BIN/pilot.sh'"); done
if [ "$host" = herdr ]; then
  tab=$(herdr tab create --label 'mobilities preview' --cwd "$ROOT" --focus)
  prev=$(jq -r '.result.root_pane.pane_id' <<<"$tab")
  herdr pane run "$prev" "${cmds[0]}"
  # --ratio is the share the split pane keeps, so each pane gets an equal width.
  for ((i=1; i<${#cmds[@]}; i++)); do
    ratio=$(awk "BEGIN { print 1 / (${#cmds[@]} - $i + 1) }")
    prev=$(herdr pane split --pane "$prev" --direction right --ratio "$ratio" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id')
    herdr pane run "$prev" "${cmds[i]}"
  done
  echo "Close with: herdr tab close $(jq -r '.result.tab.tab_id' <<<"$tab")"
else
  h=$(orca terminal create --title 'mobilities preview' --command "${cmds[0]}" --focus --json | jq -r '.result.terminal.handle')
  orca_place "$h" "${cmds[@]}"
  echo "Close with: orca terminal close --terminal $h --tab"
fi
