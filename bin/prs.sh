#!/usr/bin/env bash
# PR watch pane: your open PRs with CI and review state.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
render() {
  header "YOUR OPEN PRS"
  p=$(gh pr list --author @me --state open --json number,title,isDraft,reviewDecision,statusCheckRollup)
  [ "$(jq length <<<"$p")" -eq 0 ] && { none; return; }
  jq -r '.[] |
    ([.statusCheckRollup[]? | select(.conclusion != "SKIPPED")]) as $c |
    (if ($c|length)==0 then "no CI" elif all($c[]; .conclusion=="SUCCESS") then "CI passed"
     else "CI failed: " + ([$c[] | select(.conclusion!="SUCCESS") | .name] | join(", ")) end) as $ci |
    [.number, .title[0:44], (if .isDraft then "draft" else ((.reviewDecision // "") | ascii_downcase | gsub("_"; " ") | if .=="" then "no review" else . end) end), $ci] | @tsv' <<<"$p" |
  while IFS=$'\t' read -r n t r ci; do
    col=$DONE; [[ "$ci" == CI\ failed* ]] && col=$ERR; [ "$ci" = "no CI" ] && col=$DIM
    printf '  %s#%s%s  %-44s %s%-18s%s %s%s%s\n' "$WARN" "$n" "$RST" "$t" "$DIM" "$r" "$RST" "$col" "$ci" "$RST"
  done
}
loop 120 render
