#!/usr/bin/env bash
# Activity pane: recent commits, merged PRs, and new issues in one compact list.
set -uo pipefail
. "$(dirname "$0")/lib.sh" "$@"
need_repo
render() {
  header "ACTIVITY"
  { gh api "repos/$REPO/commits?per_page=2" | jq -r '.[] | ["commit", .sha, .sha[0:7], (.commit.message | split("\n")[0]), .commit.author.name] | @tsv'
    gh pr list --state merged --limit 2 --json number,title,author | jq -r '.[] | ["merged", .number, "#\(.number)", .title, .author.login] | @tsv'
    gh issue list --state open --limit 2 --json number,title,author | jq -r '.[] | ["issue", .number, "#\(.number)", .title, .author.login] | @tsv'
  } | while IFS=$'\t' read -r kind id label title who; do
    k=$kind; [ "$kind" = merged ] && k=pr
    printf '%s\t%s\t  %s%-6s%s %-8s %s %s(%s)%s\n' "$k" "$id" "$DIM" "$kind" "$RST" "$label" "$title" "$DIM" "$who" "$RST"
  done
}
run_pane 300 render "${nav_keys[@]}"
