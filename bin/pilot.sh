#!/usr/bin/env bash
# Pilot pane: compact project overview.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo
render() {
  header "PILOT"
  branch=$(git branch --show-current)
  files=$(git status --porcelain | wc -l | tr -d ' ')
  ahead=0 behind=0
  if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    read -r behind ahead <<<"$(git rev-list --left-right --count '@{upstream}...HEAD')"
  fi
  printf '  %s · %s  ↑%s ↓%s  %s uncommitted\n' "$REPO" "$branch" "$ahead" "$behind" "$files"
  if p=$(gh pr view --json number,title,reviewDecision,statusCheckRollup 2>/dev/null); then
    jq -r '([.statusCheckRollup[]? | select(.conclusion != "SKIPPED")]) as $c |
      (if ($c|length)==0 then "no CI" elif all($c[]; .conclusion=="SUCCESS") then "CI passed"
       else "CI failed: " + ([$c[] | select(.conclusion!="SUCCESS") | .name] | join(", ")) end) as $ci |
      "  PR #\(.number)  \(.title[0:40]) · \((.reviewDecision // "") | ascii_downcase | gsub("_"; " ") | if .=="" then "no review" else . end) · \($ci)"' <<<"$p"
  else echo '  no PR for this branch'; fi
  reviews=$(gh pr list --search 'review-requested:@me' --json number | jq length)
  assigned=$(gh issue list --assignee @me --state open --json number | jq length)
  prs=$(gh pr list --author @me --state open --json number | jq length)
  printf '  Reviews %s · Assigned %s · My PRs %s\n' "$reviews" "$assigned" "$prs"
  m=$(cfg '.milestone // empty')
  if [ -n "$m" ]; then
    if [[ "$m" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then due="${m}T00:00:00Z"
    else due=$(gh api "repos/$REPO/milestones?state=all" | jq -r --arg m "$m" 'map(select(.title==$m))[0].due_on // empty'); fi
    left=""; [ -n "$due" ] && left=" · $(jq -nr --arg d "$due" '(($d|fromdateiso8601) - now) / 86400 | floor')d left"
    printf '  Milestone: %s%s\n' "$m" "$left"
  fi
}
loop 60 render
