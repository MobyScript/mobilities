# Shared setup for mobilities scripts. Source it, do not run it.
export GH_PAGER=cat
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CFG="$ROOT/.claude/mobilities.json"
GCFG="${MOBILITIES_HOME:-$HOME/.config/mobilities}/config.json"
ONCE=0; for a in "$@"; do [ "$a" = "--once" ] && ONCE=1; done

cfg()  { jq -r "$1" "$CFG"  2>/dev/null || jq -nr "{} | $1"; }
gcfg() { jq -r "$1" "$GCFG" 2>/dev/null || jq -nr "{} | $1"; }

ansi() { case "$1" in
  black) echo 30;; red) echo 31;; green) echo 32;; yellow) echo 33;; blue) echo 34;;
  magenta) echo 35;; cyan) echo 36;; white) echo 37;;
  bright-*) echo $(( $(ansi "${1#bright-}") + 60 ));;
  \#[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]])
    local h=${1#\#}; printf '38;2;%d;%d;%d\n' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))";;
  *) echo 39;; esac; }
color() {
  local v=""
  if [ -n "${MOBILITIES_PANE:-}" ]; then
    v=$(jq -r --argjson i "$MOBILITIES_PANE" ".panes[\$i].colors.$1 // empty" "$CFG" 2>/dev/null) || :
  fi
  [ -n "$v" ] || v=$(gcfg ".colors.$1 // \"$2\"")
  ansi "$v"
}
theme() {
  case "$(gcfg '.theme // "default"')" in
    ocean)  P_HEAD=blue; P_DONE=cyan; P_WARN=yellow; P_ERR=magenta;;
    sunset) P_HEAD=magenta; P_DONE=yellow; P_WARN=bright-red; P_ERR=red;;
    mono)   P_HEAD=white; P_DONE=white; P_WARN=white; P_ERR=white;;
    light)  P_HEAD=blue; P_DONE=green; P_WARN=magenta; P_ERR=red;;
    dark)   P_HEAD=bright-cyan; P_DONE=bright-green; P_WARN=bright-yellow; P_ERR=bright-red;;
    *)      P_HEAD=cyan; P_DONE=green; P_WARN=yellow; P_ERR=red;;
  esac
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
    HEAD=$'\033['"$(color heading "$P_HEAD")m"
    DONE=$'\033['"$(color done "$P_DONE")m"
    WARN=$'\033['"$(color warning "$P_WARN")m"
    ERR=$'\033['"$(color error "$P_ERR")m"
  else BOLD=""; DIM=""; RST=""; HEAD=""; DONE=""; WARN=""; ERR=""; fi
}
theme

header() {
  local font; font=$(gcfg '.font // empty')
  if [ -n "$font" ] && command -v figlet >/dev/null 2>&1; then
    printf '%s%s' "$BOLD" "$HEAD"; figlet -f "$font" "$1"; printf '%s' "$RST"
  else printf '%s%s── %s %s\n' "$BOLD" "$HEAD" "$1" "$RST"; fi
}
none()   { printf '  %s(none)%s\n' "$DIM" "$RST"; }
loop()   { if [ "$ONCE" = 1 ]; then theme; "$2"; else while true; do theme; clear; "$2"; sleep "$1"; done; fi; }
need_repo() {
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) ||
    { printf '  %sNot a GitHub repo, or gh is not logged in. Run "gh auth status".%s\n' "$ERR" "$RST"; exit 1; }
}
