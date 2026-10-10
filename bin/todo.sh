#!/usr/bin/env bash
# Todo pane: renders mobilities-todo.md.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
F="$(repo_dir)/mobilities-todo.md"
case "${1:-}" in
  --toggle|--delete)
    [[ "${2:-}" =~ ^[0-9]+$ ]] || exit 1
    [ -f "$F" ] || exit 1
    if [ "$1" = --toggle ]; then
      awk -v n="$2" 'NR==n {if (sub(/^- \[ \] /, "- [x] ")) {} else sub(/^- \[[xX]\] /, "- [ ] ")} {print}' "$F" > "$F.tmp"
    else sed "${2}d" "$F" > "$F.tmp"; fi
    mv "$F.tmp" "$F"; exit 0;;
  --add) [[ "${2:-}" =~ [^[:space:]] ]] || exit 0
    mkdir -p "$(dirname "$F")"; printf '%s\n' "- [ ] $2" >> "$F"; exit 0;;
esac
render() {
  header "TODO"
  [ -f "$F" ] || { printf '  %sNo todo file. Create %s or ask Claude to add items.%s\n' "$DIM" "${F#$ROOT/}" "$RST"; return; }
  awk -v b="$BOLD" -v d="$DIM" -v g="$DONE" -v r="$RST" '
    /^# /           { sub(/^# /, "");           print b $0 r; next }
    /^- \[[xX]\] /  { sub(/^- \[[xX]\] /, "");  print "todo\t" NR "\t  " d g "✓ " $0 r; next }
    /^- \[ \] /     { sub(/^- \[ \] /, "");     print "todo\t" NR "\t  " b "☐ " $0 r; next }
    { gsub(/\t/, " "); print }' "$F"
}
toggle="execute-silent($SELF --toggle {2})+reload($SELF --rows)"
run_pane 5 render --header 'enter toggle · alt-enter add · ctrl-d delete · alt-f size · alt-t theme' \
  --bind "enter:$toggle" --bind "double-click:$toggle" \
  --bind "alt-enter:execute-silent($SELF --add {q})+clear-query+reload($SELF --rows)" \
  --bind "ctrl-d:execute-silent($SELF --delete {2})+reload($SELF --rows)"
