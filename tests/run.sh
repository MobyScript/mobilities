#!/usr/bin/env bash
# Runs every pane script once against fakes; fails on the first missing line.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; BIN="$HERE/../bin"
export PATH="$HERE/fakes:$PATH" FIXTURES="$HERE/fixtures" NO_COLOR=1
MOBILITIES_HOME="$(mktemp -d)"; HERDR_LOG="$(mktemp)"; export MOBILITIES_HOME HERDR_LOG
REPO="$(mktemp -d)"; cd "$REPO" && git init -q && mkdir .claude
cat > .claude/mobilities.json <<'EOT'
{"panes":[{"type":"ceo","sections":["epics","reviews","assigned","milestone","links"]},{"type":"todo"},{"type":"prs"},{"type":"activity"}],
 "epics":{"label":"epic","title":"Epic(?<n>[0-9]+)"},"stories":{"label":"user-story","title":"^US-{n}-"},
 "milestone":"Final presentation","links":{"wiki":"https://github.com/acme/app/wiki"},"banner":true}
EOT
fail=0
expect() { # expect <name> <output> <substring>...
  local name=$1 out=$2 bad=0; shift 2
  for s in "$@"; do grep -qF -- "$s" <<<"$out" || { echo "FAIL $name: missing '$s'"; echo "$out" | sed 's/^/    /'; bad=1; fail=1; }; done
  [ $bad -eq 0 ] && echo "ok   $name"
}
expect lib "$(bash -c ". '$BIN/lib.sh'; cfg '.milestone'; gcfg '.theme // \"default\"'")" "Final presentation" "default"
expect ceo "$(bash "$BIN/ceo.sh" --once)" "EPICS" "Epic1: Calendar" "1/2" "#80" "Draft mail" "#7  Fix login" "MILESTONE: Final presentation" "3/5 closed" "wiki"
printf '# Week\n\n- [x] Done thing\n- [ ] Open thing\n' > .claude/mobilities-todo.md
expect todo "$(bash "$BIN/todo.sh" --once)" "Week" "✓ Done thing" "☐ Open thing"
expect prs "$(bash "$BIN/prs.sh" --once)" "#81" "approved" "CI passed" "#82" "draft" "CI failed: test"
expect activity "$(bash "$BIN/activity.sh" --once)" "abc1234" "fix: thing" "#68" "Same-origin proxy" "#90" "New bug"
expect review "$(bash "$BIN/review.sh" 80)" "PR #80" "app/mail.py" "CI passed" "#50" "summary line" "Not tested"
grep -q "tests/test_mail.py" <<<"$(bash "$BIN/review.sh" 80)" && { echo "FAIL review: test file listed"; fail=1; }

out=$(HERDR_ENV= bash "$BIN/open.sh" 2>&1); expect open-guard "$out" "Start herdr first"
HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh" >/dev/null
expect open-layout "$(cat "$HERDR_LOG")" "pane split --pane p0 --direction right" "--direction down" "ceo.sh" "todo.sh" "prs.sh" "activity.sh"
expect banner "$(CLAUDE_PROJECT_DIR="$REPO" bash "$BIN/banner.sh" | jq -r .systemMessage)" "EPICS"

# later tasks append their checks above this line
exit $fail
