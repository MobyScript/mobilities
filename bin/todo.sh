#!/usr/bin/env bash
# Todo pane: renders .claude/mobilities-todo.md.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
F="$ROOT/.claude/mobilities-todo.md"
render() {
  header "TODO"
  [ -f "$F" ] || { printf '  %sNo todo file. Create %s or ask Claude to add items.%s\n' "$DIM" ".claude/mobilities-todo.md" "$RST"; return; }
  sed -E "s/^# (.*)/${BOLD}\1${RST}/; s/^- \[[xX]\] (.*)/  ${DIM}${DONE}✓ \1${RST}/; s/^- \[ \] (.*)/  ${BOLD}☐ \1${RST}/" "$F"
}
loop 5 render
