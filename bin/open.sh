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
panes=$(cfg '.panes // []')
[ "$(jq length <<<"$panes")" -gt 0 ] || panes=$(gcfg '.panes // []')
[ "$(jq length <<<"$panes")" -gt 0 ] || panes='[{"type":"ceo"},{"type":"todo"},{"type":"prs"},{"type":"activity"}]'
count=$(jq length <<<"$panes")
pane() { jq -r --argjson i "$1" "$2" <<<"$panes"; }
pane_cmd() {
  if [ "$(pane "$1" '.[$i] | has("cmd")')" = true ]; then pane "$1" '.[$i].cmd'
  else echo "MOBILITIES_PANE=$1 '$BIN/$(pane "$1" '.[$i].type').sh'"; fi
}
indexes=(); for ((i=0; i<count; i++)); do indexes+=("$i"); done
[ "${1:-}" = --last ] && indexes=("$((count-1))")
opened=""; for i in "${indexes[@]}"; do opened="$opened$(pane "$i" '.[$i].title // .[$i].type') "; done
if [ "$host" = orca ]; then
  if [ "$(cfg '.layout // empty')" = cockpit ]; then echo 'Orca cannot place panes left of or above the chat. Opening them on the right.'; fi
  cmd() { echo "cd '$ROOT' && $(pane_cmd "$1")"; }
  # place <handle> <index...>: <handle> already runs the first pane.
  place() {
    local h=$1; shift; local n=$# k=$(( $# / 2 ))
    [ "$n" -le 1 ] && return
    [ "$k" -eq 0 ] && k=1
    local rest=("${@:k+1}") new
    new=$(orca terminal split --terminal "$h" --direction horizontal --command "$(cmd "${rest[0]}")" --json | jq -r '.result.split.handle')
    place "$h" "${@:1:k}"
    place "$new" "${rest[@]}"
  }
  set -- "${indexes[@]}"
  root=$(orca terminal split --terminal "$ORCA_TERMINAL_HANDLE" --direction vertical --command "$(cmd "$1")" --json | jq -r '.result.split.handle')
  place "$root" "$@"
  echo "Opened: ${opened% }"; exit 0
fi
if [ "$(cfg '.layout // empty')" = cockpit ]; then
  chat="${HERDR_PANE_ID:?}"
  split() {
    new=$(herdr pane split --pane "$1" --direction "$2" --ratio "$3" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id')
    herdr pane run "$new" "$(pane_cmd "$4")"
  }
  for side in top left right; do
    group=(); for i in "${indexes[@]}"; do
      [ "$(pane "$i" '.[$i].side // "right"')" = "$side" ] && group+=("$i")
    done
    [ "${#group[@]}" -eq 0 ] && continue
    case "$side" in
      top) split "$chat" down 0.2 "${group[0]}"; herdr pane swap --source-pane "$chat" --target-pane "$new"; anchor=$new; direction=right;;
      left) split "$chat" right 0.25 "${group[0]}"; herdr pane swap --source-pane "$chat" --target-pane "$new"; anchor=$new; direction=down;;
      right) split "$chat" right 0.66 "${group[0]}"; anchor=$new; direction=down;;
    esac
    for ((j=1; j<${#group[@]}; j++)); do
      ratio=$(awk "BEGIN { print 1 / (${#group[@]} - $j + 1) }")
      split "$anchor" "$direction" "$ratio" "${group[j]}"
      anchor=$new
    done
  done
  echo "Opened: ${opened% }"; exit 0
fi
# --ratio is the share the split pane keeps. The CEO pane gets a double share.
w() { if [ "$(pane "$1" '.[$i].type')" = ceo ]; then echo 2; else echo 1; fi; }
total=0; for i in "${indexes[@]}"; do total=$((total + $(w "$i"))); done
prev="${HERDR_PANE_ID:?}"; dir=right; ratio=0.5; prior=""
for i in "${indexes[@]}"; do
  if [ -n "$prior" ]; then
    dir=down; ratio=$(awk "BEGIN { print $(w "$prior") / $total }"); total=$((total - $(w "$prior")))
  fi
  new=$(herdr pane split --pane "$prev" --direction "$dir" --ratio "$ratio" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id')
  herdr pane run "$new" "$(pane_cmd "$i")"
  prev=$new; prior=$i
done
echo "Opened: ${opened% }"
