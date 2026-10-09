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
# later tasks append their checks above this line
exit $fail
