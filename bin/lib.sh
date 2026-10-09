# Shared setup for mobilities scripts. Source it, do not run it.
export GH_PAGER=cat
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CFG="$ROOT/.claude/mobilities.json"
GCFG="${MOBILITIES_HOME:-$HOME/.config/mobilities}/config.json"
ONCE=0; for a in "$@"; do [ "$a" = "--once" ] && ONCE=1; done

cfg()  { jq -r "$1" "$CFG"  2>/dev/null || jq -nr "{} | $1"; }
gcfg() { jq -r "$1" "$GCFG" 2>/dev/null || jq -nr "{} | $1"; }

# Theme: preset name or explicit colors from the shared config.
ansi() { case "$1" in
  black) echo 30;; red) echo 31;; green) echo 32;; yellow) echo 33;; blue) echo 34;;
  magenta) echo 35;; cyan) echo 36;; white) echo 37;; bright-*) echo $(( $(ansi "${1#bright-}") + 60 ));; *) echo 39;; esac; }
case "$(gcfg '.theme // "default"')" in
  ocean)  P_HEAD=blue;    P_DONE=cyan;  P_WARN=yellow; P_ERR=magenta;;
  sunset) P_HEAD=magenta; P_DONE=yellow; P_WARN=bright-red; P_ERR=red;;
  mono)   P_HEAD=white;   P_DONE=white; P_WARN=white;  P_ERR=white;;
  *)      P_HEAD=cyan;    P_DONE=green; P_WARN=yellow; P_ERR=red;;
esac
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  HEAD=$'\033['"$(ansi "$(gcfg ".colors.heading // \"$P_HEAD\"")")m"
  DONE=$'\033['"$(ansi "$(gcfg ".colors.done // \"$P_DONE\"")")m"
  WARN=$'\033['"$(ansi "$(gcfg ".colors.warning // \"$P_WARN\"")")m"
  ERR=$'\033['"$(ansi "$(gcfg ".colors.error // \"$P_ERR\"")")m"
else BOLD=""; DIM=""; RST=""; HEAD=""; DONE=""; WARN=""; ERR=""; fi

header() { printf '%s%s── %s %s\n' "$BOLD" "$HEAD" "$1" "$RST"; }
none()   { printf '  %s(none)%s\n' "$DIM" "$RST"; }
loop()   { if [ "$ONCE" = 1 ]; then "$2"; else while true; do clear; "$2"; sleep "$1"; done; fi; }
