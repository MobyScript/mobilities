#!/usr/bin/env bash
# Activity pane: recent commits, merged PRs, and new issues in one compact list.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo
render() {
  header "ACTIVITY"
  gh api "repos/$REPO/commits?per_page=2" | jq -r '.[] | "\(.sha[0:7])\t\(.commit.message | split("\n")[0])\t\(.commit.author.name)"' | sed 's/^/commit\t/'
  gh pr list --state merged --limit 2 --json number,title,author | jq -r '.[] | "merged\t#\(.number)\t\(.title)\t\(.author.login)"'
  gh issue list --state open --limit 2 --json number,title,author | jq -r '.[] | "issue\t#\(.number)\t\(.title)\t\(.author.login)"'
}
show() { render | while IFS=$'\t' read -r kind id title who; do
  [ -z "$id" ] && { echo "$kind"; continue; }
  printf '  %s%-6s%s %-8s %s %s(%s)%s\n' "$DIM" "$kind" "$RST" "$id" "$title" "$DIM" "$who" "$RST"; done; }
loop 300 show
