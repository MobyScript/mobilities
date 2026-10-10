#!/usr/bin/env bash
# PR watch pane: your open PRs with CI and review state.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo
rows() {
  local p=${1:-$(gh pr list --author @me --state open --json number,title,isDraft,reviewDecision,statusCheckRollup)}
  jq -r '.[] |
    ([.statusCheckRollup[]? | select(.conclusion != "SKIPPED")]) as $c |
    (if ($c|length)==0 then "no CI" elif all($c[]; .conclusion=="SUCCESS") then "CI passed"
     else "CI failed: " + ([$c[] | select(.conclusion!="SUCCESS") | .name] | join(", ")) end) as $ci |
    [.number, .title[0:32], (if .isDraft then "draft" else ((.reviewDecision // "") | ascii_downcase | gsub("_"; " ") | if .=="" then "no review" else . end) end), $ci] | @tsv' <<<"$p"
}
[ "${1:-}" = --list ] && { rows; exit 0; }
render() {
  header "YOUR OPEN PRS"
  p=$(gh pr list --author @me --state open --json number,title,isDraft,reviewDecision,statusCheckRollup)
  [ "$(jq length <<<"$p")" -eq 0 ] && { none; return; }
  rows "$p" |
  while IFS=$'\t' read -r n t r ci; do
    col=$DONE; [[ "$ci" == CI\ failed* ]] && col=$ERR; [ "$ci" = "no CI" ] && col=$DIM
    printf '  %s#%s%s  %-32s %s%-18s%s %s%s%s\n' "$WARN" "$n" "$RST" "$t" "$DIM" "$r" "$RST" "$col" "$ci" "$RST"
  done
}
if [ "$ONCE" = 0 ] && command -v fzf >/dev/null 2>&1; then
  printf -v self '%q' "$0"
  list="$self --list"
  portfile=$(mktemp)
  # ponytail: curl is shipped with macOS; ctrl-r still refreshes if the timer fails.
  ( while [ ! -s "$portfile" ]; do sleep 0.1; done
    while sleep 120; do curl -fsS -X POST "http://127.0.0.1:$(cat "$portfile")" -d "reload($list)" >/dev/null 2>&1 || :; done ) & watcher=$!
  rows | fzf --listen 0 --delimiter $'\t' --with-nth 1.. --color "header:$(color_value heading "$P_HEAD"),pointer:$(color_value warning "$P_WARN")" --header 'enter diff · ctrl-r reload' \
    --preview 'gh pr view {1}; gh pr checks {1}' \
    --bind "start:execute-silent(printf %s \"\$FZF_PORT\" > '$portfile')" \
    --bind "enter:execute(gh pr diff {1} --color=always | less -R)" \
    --bind "ctrl-r:reload($list)" >/dev/null
  kill "$watcher" 2>/dev/null || :; rm -f "$portfile"; exit 0
fi
loop 120 render
