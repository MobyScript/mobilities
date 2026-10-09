#!/usr/bin/env bash
# Short PR brief: what changed, CI state, linked issue (summarized), discussion summary.
# Usage: review.sh <PR#>
set -euo pipefail
. "$(dirname "$0")/lib.sh"

PR="${1:?usage: review.sh <PR#>}"
TEST_FILE_PATTERN='(^|/)(tests?|__tests__)/|(^|/)test_|\.(test|spec)\.'

# summarize <prompt> <raw text> -> claude's answer, or the raw text on failure
summarize() { claude -p "$1" 2>/dev/null || { echo "(claude unavailable, raw text follows)"; printf '%s\n' "$2"; }; }
# mdlite: **bold** -> bold, "- " bullets -> "•", indent 4 spaces
mdlite() { sed -E "s/\*\*([^*]+)\*\*/${BOLD}\1${RST}/g; s/^([[:space:]]*)[-*] /\1• /" | sed 's/^/    /'; }

PR_JSON=$(gh pr view "$PR" --json number,title,url,author,body,additions,deletions,files,statusCheckRollup,closingIssuesReferences,comments)

header "PR #$PR"
jq -r '"  " + .title + "\n  by " + .author.login + "  +" + (.additions|tostring) + "/-" + (.deletions|tostring) + "\n  " + .url' <<<"$PR_JSON"

echo
header "FILES (no tests)"
jq -r --arg pat "$TEST_FILE_PATTERN" '.files[] | select(.path | test($pat) | not) | "  " + .changeType + "  " + .path' <<<"$PR_JSON"

echo
header "CI"
CHECKS=$(jq '[.statusCheckRollup[]? | select(.conclusion != "SKIPPED")]' <<<"$PR_JSON")
if [ "$(jq length <<<"$CHECKS")" -eq 0 ]; then
  printf '  %s(no checks reported)%s\n' "$DIM" "$RST"
elif jq -e 'all(.conclusion == "SUCCESS")' <<<"$CHECKS" >/dev/null; then
  printf '  %sCI passed%s\n' "$DONE" "$RST"
else
  printf '  %sCI failed%s — %s\n' "$ERR" "$RST" "$(jq -r '[.[] | select(.conclusion != "SUCCESS") | .name] | join(", ")' <<<"$CHECKS")"
fi

echo
header "LINKED ISSUE"
ISSUE_NUM=$(jq -r '.closingIssuesReferences[0].number // empty' <<<"$PR_JSON")
# fallback: PR titled "<issue#> <description>"
[ -n "$ISSUE_NUM" ] || ISSUE_NUM=$(jq -r '.title' <<<"$PR_JSON" | grep -oE '^[0-9]+' || true)
if [ -n "$ISSUE_NUM" ] && gh issue view "$ISSUE_NUM" --json number >/dev/null 2>&1; then
  ISSUE_JSON=$(gh issue view "$ISSUE_NUM" --json number,title,body,state)
  jq -r '"  #" + (.number|tostring) + " [" + .state + "] " + .title' <<<"$ISSUE_JSON"
  echo
  BODY=$(jq -r '.body' <<<"$ISSUE_JSON")
  summarize "In plain simple English, a short bullet list (5 lines max), summarize what this user story needs and what looks done vs still open. No markdown headers, no jargon. Text:

$BODY" "$BODY" | mdlite
else
  echo "  (no linked issue found)"
fi

echo
header "COMMENTS"
if [ "$(jq '.comments | length' <<<"$PR_JSON")" -eq 0 ]; then none
else
  THREAD=$(jq -r '.comments[] | .author.login + " said:\n" + .body + "\n---"' <<<"$PR_JSON")
  summarize "In plain simple English, a very short summary (3 lines max) of this PR comment thread: who raised what, who responded, and where it landed. No markdown. Thread:

$THREAD" "$THREAD" | mdlite
fi

echo
header "WARNINGS THE AUTHOR WROTE"
FLAGS=$(jq -r '.body' <<<"$PR_JSON" | grep -inE 'not yet|todo|fixme|not tested|known issue|workaround|deliberate difference' || true)
if [ -z "$FLAGS" ]; then echo "  (none)"; else echo "$FLAGS" | sed 's/^/  /'; fi
