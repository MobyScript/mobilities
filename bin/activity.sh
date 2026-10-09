#!/usr/bin/env bash
# Activity pane: recent commits, merged PRs, new issues.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
render() {
  header "RECENT COMMITS"
  gh api "repos/$REPO/commits?per_page=8" | jq -r '.[] | "  \(.sha[0:7])  \(.commit.message | split("\n")[0])  (\(.commit.author.name))"'
  echo; header "MERGED PRS"
  gh pr list --state merged --limit 5 --json number,title,author | jq -r '.[] | "  #\(.number)  \(.title)  (\(.author.login))"'
  echo; header "NEW ISSUES"
  gh issue list --state open --limit 5 --json number,title,author | jq -r '.[] | "  #\(.number)  \(.title)  (\(.author.login))"'
}
loop 300 render
