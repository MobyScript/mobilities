#!/usr/bin/env bash
# Opens the configured panes next to the calling Orca or herdr pane.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
host=$(cfg '.host // empty')
if [ -z "$host" ]; then
  if [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; then host=orca; elif [ "${HERDR_ENV:-}" = 1 ]; then host=herdr; fi
fi
if { [ "$host" = orca ] && [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; } || { [ "$host" = herdr ] && [ "${HERDR_ENV:-}" = 1 ]; }; then :
else echo 'Open this project in Orca (https://orca.build) or herdr (https://herdr.dev), start Claude Code there, and run /mobilities again.'; exit 2; fi
types=$(cfg '[.panes[]?.type] | if length>0 then .[] else empty end')
[ -n "$types" ] || types=$(gcfg '(.layout // ["ceo","todo","prs","activity"])[]')
if [ "$host" = orca ]; then
  cmd() { echo "cd '$ROOT' && '$BIN/$1.sh'"; }
  # place <handle> <type...>: <handle> already runs the first type. Keep the first
  # floor(n/2) types above, put the rest below, so heights come out equal.
  place() {
    local h=$1; shift; local n=$# k=$(( $# / 2 ))
    [ "$n" -le 1 ] && return
    [ "$k" -eq 0 ] && k=1
    local rest=("${@:k+1}") new
    new=$(orca terminal split --terminal "$h" --direction horizontal --command "$(cmd "${rest[0]}")" --json | jq -r '.result.split.handle')
    place "$h" "${@:1:k}"
    place "$new" "${rest[@]}"
  }
  set -- $types
  root=$(orca terminal split --terminal "$ORCA_TERMINAL_HANDLE" --direction vertical --command "$(cmd "$1")" --json | jq -r '.result.split.handle')
  place "$root" "$@"
  echo "Opened: $types" | tr '\n' ' '; echo; exit 0
fi
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
