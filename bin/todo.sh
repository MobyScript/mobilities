#!/usr/bin/env bash
# Todo pane: renders .claude/mobilities-todo.md.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
F="$ROOT/.claude/mobilities-todo.md"
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
  --list) awk '/^- \[[ xX]\] / {print NR "\t" $0}' "$F" 2>/dev/null; exit 0;;
esac
render() {
  header "TODO"
  [ -f "$F" ] || { printf '  %sNo todo file. Create %s or ask Claude to add items.%s\n' "$DIM" ".claude/mobilities-todo.md" "$RST"; return; }
  sed -E "s/^# (.*)/${BOLD}\1${RST}/; s/^- \[[xX]\] (.*)/  ${DIM}${DONE}✓ \1${RST}/; s/^- \[ \] (.*)/  ${BOLD}☐ \1${RST}/" "$F"
}
if [ "$ONCE" = 0 ] && command -v fzf >/dev/null 2>&1; then
  export F
  printf -v self '%q' "$0"
  list="$self --list"
  portfile=$(mktemp)
  # ponytail: curl is shipped with macOS; a missing local reload leaves manual keys working.
  ( while [ ! -s "$portfile" ]; do sleep 0.1; done
    while sleep 5; do curl -fsS -X POST "http://127.0.0.1:$(cat "$portfile")" -d "reload($list)" >/dev/null 2>&1 || :; done ) & watcher=$!
  eval "$list" | fzf --listen 0 --delimiter $'\t' --with-nth 2.. --color "header:$(color_value heading "$P_HEAD"),pointer:$(color_value warning "$P_WARN")" --header 'enter toggle · alt-enter add query · ctrl-d delete' \
    --bind "start:execute-silent(printf %s \"\$FZF_PORT\" > '$portfile')" \
    --bind "enter:execute-silent($self --toggle {1})+reload($list)" \
    --bind "alt-enter:execute-silent($self --add {q})+reload($list)" \
    --bind "ctrl-d:execute-silent($self --delete {1})+reload($list)" >/dev/null
  kill "$watcher" 2>/dev/null || :; rm -f "$portfile"; exit 0
fi
loop 5 render
