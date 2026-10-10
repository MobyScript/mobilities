#!/usr/bin/env bash
# PR watch pane: your open PRs with CI and review state.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo
render() {
  header "YOUR OPEN PRS"
  p=$(gh pr list --author @me --state open --json number,title,isDraft,reviewDecision,statusCheckRollup)
  [ "$(jq length <<<"$p")" -eq 0 ] && { none; return; }
  jq -r '.[] |
    ([.statusCheckRollup[]? | select(.conclusion != "SKIPPED")]) as $c |
    (if ($c|length)==0 then "no CI" elif all($c[]; .conclusion=="SUCCESS") then "CI passed"
     else "CI failed: " + ([$c[] | select(.conclusion!="SUCCESS") | .name] | join(", ")) end) as $ci |
    [.number, .title[0:32], (if .isDraft then "draft" else ((.reviewDecision // "") | ascii_downcase | gsub("_"; " ") | if .=="" then "no review" else . end) end), $ci] | @tsv' <<<"$p" |
  while IFS=$'\t' read -r n t r ci; do
    col=$DONE; [[ "$ci" == CI\ failed* ]] && col=$ERR; [ "$ci" = "no CI" ] && col=$DIM
    printf 'pr\t%s\t  %s#%s%s  %-32s %s%-18s%s %s%s%s\n' "$n" "$WARN" "$n" "$RST" "$t" "$DIM" "$r" "$RST" "$col" "$ci" "$RST"
  done
}
diff='execute([ {1} = pr ] && gh pr diff {2} --color=always | less -R)'
run_pane 120 render --header 'enter diff · ? preview · ctrl-r reload · alt-f size · alt-t theme' \
  --preview '[ {1} = pr ] && gh pr view {2} && gh pr checks {2}' --preview-window 'right,50%,hidden' \
  --bind '?:toggle-preview' --bind "enter:$diff" --bind "double-click:$diff"
