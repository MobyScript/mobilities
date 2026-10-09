#!/usr/bin/env bash
# CEO pane: epics, review queue, assigned issues, milestone countdown, links.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo

bar() { # bar <done> <total>
  local d=$1 t=$2 i; [ "$t" -eq 0 ] && { printf '%s[ no stories ]%s' "$DIM" "$RST"; return; }
  printf '%s' "$DONE"; for ((i=0; i<d*10/t; i++)); do printf '━'; done
  printf '%s' "$DIM";  for ((i=d*10/t; i<10; i++)); do printf '─'; done
  printf '%s %d/%d' "$RST" "$d" "$t"
}
want() { local s; s=$(cfg '[.panes[]? | select(.type=="ceo") | .sections[]?] | join(" ")'); [ -z "$s" ] || [[ " $s " == *" $1 "* ]]; }

render() {
  if want epics; then
    header "EPICS"
    gh issue list --state all --limit 300 --json number,title,state,labels | jq -r \
      --arg el "$(cfg '.epics.label // "epic"')" --arg et "$(cfg '.epics.title // "Epic(?<n>[0-9]+)"')" \
      --arg sl "$(cfg '.stories.label // "user-story"')" --arg st "$(cfg '.stories.title // "^US-{n}-"')" '
      . as $all | .[] | select(any(.labels[]; .name==$el)) |
      (.title | capture($et).n? // "") as $n | select($n != "") |
      ($all | map(select(any(.labels[]; .name==$sl) and (.title | test($st | sub("\\{n\\}"; $n)))))) as $s |
      [((.title + (" " * 50))[0:50]), ($s | map(select(.state=="CLOSED")) | length), ($s | length)] | @tsv' |
    while IFS=$'\t' read -r title d t; do printf '  %s ' "$title"; bar "$d" "$t"; echo; done
    echo
  fi
  if want reviews; then
    header "REVIEW QUEUE"
    r=$(gh pr list --search "review-requested:@me" --json number,title,author)
    [ "$(jq length <<<"$r")" -eq 0 ] && none
    jq -r '.[] | [.number, .title[0:48], .author.login] | @tsv' <<<"$r" |
      while IFS=$'\t' read -r n t a; do printf '  %s#%s%s  %-48s %s(%s)%s\n' "$WARN" "$n" "$RST" "$t" "$DIM" "$a" "$RST"; done
    echo
  fi
  if want assigned; then
    header "ASSIGNED TO YOU"
    a=$(gh issue list --assignee @me --state open --json number,title)
    [ "$(jq length <<<"$a")" -eq 0 ] && none
    jq -r '.[] | "  #\(.number)  \(.title)"' <<<"$a"; echo
  fi
  if want milestone && [ -n "$(cfg '.milestone // empty')" ]; then
    m=$(cfg '.milestone')
    if [[ "$m" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then due="${m}T00:00:00Z"; prog=""
    else
      ms=$(gh api "repos/$REPO/milestones?state=all" | jq --arg m "$m" 'map(select(.title==$m))[0] // {}')
      due=$(jq -r '.due_on // empty' <<<"$ms")
      prog=$(jq -r 'select(.title) | "\(.closed_issues)/\(.closed_issues + .open_issues) closed"' <<<"$ms")
    fi
    left=""; [ -n "$due" ] && left=" · $(jq -nr --arg d "$due" '(($d|fromdateiso8601) - now) / 86400 | floor')d left"
    header "MILESTONE: $m$left"; [ -n "$prog" ] && echo "  $prog"; echo
  fi
  if want links; then
    header "LINKS"
    printf '  %sissues%s %s\n' "$DIM" "$RST" "https://github.com/$REPO/issues"
    cfg '.links // {} | to_entries[] | "  \(.key) \(.value)"'
  fi
}
loop 600 render
