# Shared setup for mobilities scripts. Source it, do not run it.
export GH_PAGER=cat
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOMEDIR="${MOBILITIES_HOME:-$HOME/.config/mobilities}"
GCFG="$HOMEDIR/config.json"
# Repo files live in $MOBILITIES_DIR, else .mobilities/ if it has a config, else .claude/.
repo_dir() {
  if [ -n "${MOBILITIES_DIR:-}" ]; then
    case "$MOBILITIES_DIR" in /*) echo "$MOBILITIES_DIR";; *) echo "$ROOT/$MOBILITIES_DIR";; esac
  elif [ -f "$ROOT/.mobilities/mobilities.json" ]; then echo "$ROOT/.mobilities"
  else echo "$ROOT/.claude"; fi
}
CFG="$(repo_dir)/mobilities.json"
ONCE=0 ROWS=0; for a in "$@"; do case "$a" in --once) ONCE=1;; --rows) ROWS=1;; esac; done
printf -v SELF '%q' "$0"

cfg()  { jq -r "$1" "$CFG"  2>/dev/null || jq -nr "{} | $1"; }
gcfg() { jq -r "$1" "$GCFG" 2>/dev/null || jq -nr "{} | $1"; }
tty_out() { [ -t 1 ] || [ -n "${FZF_COLUMNS:-}" ]; }
heading_size() {
  local s=${MOBILITIES_HEADING:-$(gcfg '.heading // empty')}
  [ -n "$s" ] || { [ -n "$(gcfg '.font // empty')" ] && s=big || s=off; }
  echo "$s"
}
heading_font() { # heading_font <small|big>
  if [ "$1" = small ]; then gcfg ".fonts.small // \"$HOMEDIR/fonts/pagga.tlf\""
  else gcfg ".fonts.big // .font // \"$HOMEDIR/fonts/ansi-shadow.flf\""; fi
}
set_heading() {
  mkdir -p "$HOMEDIR"; [ -f "$GCFG" ] || echo '{}' > "$GCFG"
  jq --arg h "$1" '.heading = $h' "$GCFG" > "$GCFG.tmp" && mv "$GCFG.tmp" "$GCFG"
}
open_row() { # open_row <kind> <id>: shows the details in the terminal.
  case "$1:$2" in
    pr:*)     [[ "$2" =~ ^[0-9]+$ ]] && { gh pr view "$2" --comments; gh pr checks "$2"; } 2>&1 | less -R;;
    issue:*)  [[ "$2" =~ ^[0-9]+$ ]] && gh issue view "$2" --comments 2>&1 | less -R;;
    commit:*) [[ "$2" =~ ^[0-9a-f]+$ ]] && git -C "$ROOT" show --color=always "$2" | less -R;;
    link:*)   [[ "$2" =~ ^https?:// ]] && { if command -v w3m >/dev/null 2>&1; then w3m "$2"; else open "$2"; fi; };;
  esac
  return 0
}
case "${1:-}" in
  --cycle-heading) case "$(heading_size)" in off) set_heading small;; small) set_heading big;; *) set_heading off;; esac; exit 0;;
  --heading) [[ "${2:-}" =~ ^(off|small|big)$ ]] || { echo 'Use off, small, or big.' >&2; exit 1; }; set_heading "$2"; exit 0;;
  --open) open_row "${2:-}" "${3:-}"; exit 0;;
esac

ansi() { case "$1" in
  black) echo 30;; red) echo 31;; green) echo 32;; yellow) echo 33;; blue) echo 34;;
  magenta) echo 35;; cyan) echo 36;; white) echo 37;;
  bright-*) echo $(( $(ansi "${1#bright-}") + 60 ));;
  \#[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]])
    local h=${1#\#}; printf '38;2;%d;%d;%d\n' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))";;
  *) echo 39;; esac; }
color_value() {
  local v=""
  if [ -n "${MOBILITIES_PANE:-}" ]; then
    v=$(jq -r --argjson i "$MOBILITIES_PANE" ".panes[\$i].colors.$1 // empty" "$CFG" 2>/dev/null) || :
  fi
  [ -n "$v" ] || v=$(gcfg ".colors.$1 // \"$2\"")
  printf '%s\n' "$v"
}
color() { ansi "$(color_value "$1" "$2")"; }
theme() {
  case "${MOBILITIES_THEME:-$(gcfg '.theme // "default"')}" in
    ocean)  P_HEAD=bright-blue; P_DONE=cyan; P_WARN=yellow; P_ERR=magenta;;
    sunset) P_HEAD=magenta; P_DONE=yellow; P_WARN=bright-red; P_ERR=red;;
    mono)   P_HEAD=white; P_DONE=white; P_WARN=white; P_ERR=white;;
    light)  P_HEAD=blue; P_DONE=green; P_WARN=magenta; P_ERR=red;;
    dark)   P_HEAD=bright-cyan; P_DONE=bright-green; P_WARN=bright-yellow; P_ERR=bright-red;;
    *)      P_HEAD=cyan; P_DONE=green; P_WARN=yellow; P_ERR=red;;
  esac
  if tty_out && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
    HEAD=$'\033['"$(color heading "$P_HEAD")m"
    DONE=$'\033['"$(color done "$P_DONE")m"
    WARN=$'\033['"$(color warning "$P_WARN")m"
    ERR=$'\033['"$(color error "$P_ERR")m"
  else BOLD=""; DIM=""; RST=""; HEAD=""; DONE=""; WARN=""; ERR=""; fi
  HEADED=0
}
theme

# width <text>: the widest line, counted in characters, not bytes.
width() ( LC_ALL=en_US.UTF-8; m=0; while IFS= read -r l; do [ "${#l}" -gt "$m" ] && m=${#l}; done <<<"$1"; echo "$m" )
# Only the first heading of a render may be big, and only if it fits.
header() {
  local size font out l
  size=$(heading_size)
  if [ "$HEADED" = 0 ] && [ "$size" != off ] && tty_out && command -v figlet >/dev/null 2>&1 &&
     font=$(heading_font "$size") && out=$(figlet -w 999 -f "$font" "$1" 2>/dev/null) && [ -n "$out" ] &&
     [ "$(width "$out")" -le "${FZF_COLUMNS:-$(tput cols 2>/dev/null || echo 80)}" ]; then
    HEADED=1
    while IFS= read -r l; do printf '%s%s%s%s\n' "$BOLD" "$HEAD" "$l" "$RST"; done <<<"$out"
    return
  fi
  HEADED=1; printf '%s%s── %s %s\n' "$BOLD" "$HEAD" "$1" "$RST"
}
none()   { printf '  %s(none)%s\n' "$DIM" "$RST"; }
to_rows() { awk -F'\t' 'NF >= 3 { print; next } { print "\t\t" $0 }'; }
plain()   { awk -F'\t' 'NF >= 3 { sub(/^[^\t]*\t[^\t]*\t/, "") } { print }'; }
paint()   { [ -z "${MOBILITIES_PREVIEW:-}" ] || printf '%s%s%s\n' "$DIM" "$MOBILITIES_PREVIEW" "$RST"; "$1"; }
nav_keys=(--no-input --header 'enter open · f size · r reload'
  --bind "f:execute-silent($SELF --cycle-heading)+reload($SELF --rows)" --bind "r:reload($SELF --rows)")
pick() { # pick <reload-seconds> [fzf args...]
  local secs=$1 list="$SELF --rows" portfile watcher; shift
  portfile=$(mktemp)
  # ponytail: curl ships with macOS; ctrl-r still reloads if the timer fails.
  ( while [ ! -s "$portfile" ]; do sleep 0.1; done
    while sleep "$secs"; do curl -fsS -X POST "http://127.0.0.1:$(cat "$portfile")" -d "reload($list)" >/dev/null 2>&1 || :; done ) & watcher=$!
  fzf --ansi --listen 0 --layout=reverse --no-sort --delimiter $'\t' --with-nth 3.. \
    --bind "start:execute-silent(printf %s \"\$FZF_PORT\" > '$portfile')+reload($list)" \
    --bind "enter:execute($SELF --open {1} {2})" --bind "double-click:execute($SELF --open {1} {2})" \
    --bind "ctrl-r:reload($list)" --bind "alt-f:execute-silent($SELF --cycle-heading)+reload($list)" \
    "$@" </dev/null >/dev/null
  kill "$watcher" 2>/dev/null || :; wait "$watcher" 2>/dev/null || :; rm -f "$portfile"
}
run_pane() { # run_pane <seconds> <render-fn> [fzf args...]
  local secs=$1 fn=$2; shift 2
  if [ "$ROWS" = 1 ]; then paint "$fn" | to_rows; exit 0; fi
  if [ "$ONCE" = 0 ] && command -v fzf >/dev/null 2>&1; then pick "$secs" "$@"; exit 0; fi
  if [ "$ONCE" = 1 ]; then theme; paint "$fn" | plain; exit 0; fi
  while true; do theme; clear; paint "$fn" | plain; sleep "$secs"; done
}
need_repo() {
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) ||
    { printf '  %sNot a GitHub repo, or gh is not logged in. Run "gh auth status".%s\n' "$ERR" "$RST"; exit 1; }
}
