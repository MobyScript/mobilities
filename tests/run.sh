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

export ORCA_LOG="$(mktemp)"
out=$(HERDR_ENV= ORCA_TERMINAL_HANDLE= bash "$BIN/open.sh" 2>&1); expect open-guard "$out" "Open this project in Orca"
ORCA_TERMINAL_HANDLE=t0 HERDR_ENV= bash "$BIN/open.sh" >/dev/null
expect orca-layout "$(cat "$ORCA_LOG")" "terminal split --terminal t0 --direction vertical" "--direction horizontal" "ceo.sh" "todo.sh" "prs.sh" "activity.sh"
[ "$(grep -c 'terminal split' "$ORCA_LOG")" -eq 4 ] || { echo "FAIL orca-layout: expected 4 splits"; fail=1; }
ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh" >/dev/null
expect open-layout "$(cat "$HERDR_LOG")" "pane split --pane p0 --direction right --ratio 0.5" "--direction down --ratio 0.4" "--ratio 0.333333" "--ratio 0.5 --cwd" "ceo.sh" "todo.sh" "prs.sh" "activity.sh"
expect banner "$(CLAUDE_PROJECT_DIR="$REPO" bash "$BIN/banner.sh" | jq -r .systemMessage)" "EPICS"

for s in ceo prs activity; do expect "no-repo-$s" "$(FAKE_NO_REPO=1 bash "$BIN/$s.sh" --once 2>&1)" "Not a GitHub repo"; done
out=$(bash -c ". '$BIN/lib.sh'; ansi '#ff8000'; ansi bright-red")
[ "$out" = $'38;2;255;128;0\n91' ] && echo 'ok   ansi' || { echo "FAIL ansi: $out"; fail=1; }
cat > .claude/mobilities.json <<'EOT'
{"host":"herdr","panes":[{"type":"ceo"},{"type":"cmd","cmd":"lazygit --path .","title":"Git"}]}
EOT
: > "$HERDR_LOG"
out=$(ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh")
expect cmd-pane "$(cat "$HERDR_LOG")" "lazygit --path ." "MOBILITIES_PANE=0" "--direction down --ratio 0.666667"
expect cmd-title "$out" "Opened: ceo Git"
: > "$HERDR_LOG"
out=$(ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh" --last)
expect open-last "$(cat "$HERDR_LOG")" "pane split --pane p0 --direction right --ratio 0.5" "lazygit --path ."
[ "$(grep -c 'pane split' "$HERDR_LOG")" -eq 1 ] || { echo "FAIL open-last: expected 1 split"; fail=1; }
theme_check=$(cat <<'EOT'
source "$LIB_FOR_TEST"
[[ "$DONE" == $'\033[32m' && "$HEAD" != *$'\n'* ]] && printf 'theme-ok\n'
EOT
)
printf -v linux_cmd 'bash -c %q' "$theme_check"
# ponytail: script can exit before forwarding the child's output.
for attempt in 1 2 3; do
  out=$(env HOME="$MOBILITIES_HOME" NO_COLOR= MOBILITIES_HOME= LIB_FOR_TEST="$BIN/lib.sh" script -q /dev/null bash -c "$theme_check" 2>/dev/null) ||
    out=$(env HOME="$MOBILITIES_HOME" NO_COLOR= MOBILITIES_HOME= LIB_FOR_TEST="$BIN/lib.sh" script -qc "$linux_cmd" /dev/null 2>/dev/null)
  [[ "$out" == *theme-ok* ]] && break
done
[[ "$out" == *theme-ok* ]] && echo 'ok   theme-color' || { echo 'FAIL theme-color'; fail=1; }
jq '.milestone="Final presentation"' .claude/mobilities.json > .claude/mobilities.tmp && mv .claude/mobilities.tmp .claude/mobilities.json
expect pilot "$(bash "$BIN/pilot.sh" --once)" "acme/app" "$(git branch --show-current)" "PR #80" "Reviews 1 · Assigned 1 · My PRs 2" "Milestone: Final presentation"
printf '# Week\n- [ ] First\n- [x] Second\n' > .claude/mobilities-todo.md
bash "$BIN/todo.sh" --toggle 2
expect todo-toggle "$(cat .claude/mobilities-todo.md)" "- [x] First"
bash "$BIN/todo.sh" --toggle 3
expect todo-untoggle "$(cat .claude/mobilities-todo.md)" "- [ ] Second"
bash "$BIN/todo.sh" --add Third
expect todo-add "$(cat .claude/mobilities-todo.md)" "- [ ] Third"
bash "$BIN/todo.sh" --delete 2
expect todo-delete "$(cat .claude/mobilities-todo.md)" "- [ ] Second" "- [ ] Third"
grep -qF 'First' .claude/mobilities-todo.md && { echo 'FAIL todo-delete: First remains'; fail=1; }
cat > .claude/mobilities.json <<'EOT'
{"host":"herdr","layout":"cockpit","panes":[{"type":"pilot","side":"top"},{"type":"todo","side":"left"},{"type":"activity","side":"left"},{"type":"prs","side":"right"},{"type":"ceo","side":"right"}]}
EOT
: > "$HERDR_LOG"
ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh" >/dev/null
expect cockpit "$(cat "$HERDR_LOG")" "pane split --pane p0 --direction down --ratio 0.2" "pane split --pane p0 --direction right --ratio 0.25" "pane split --pane p0 --direction right --ratio 0.66" "--direction down --ratio 0.5" "pane swap --source-pane p0 --target-pane"
[ "$(grep -c 'pane swap' "$HERDR_LOG")" -eq 2 ] || { echo 'FAIL cockpit: expected 2 swaps'; fail=1; }
[ "$(grep -c 'pane split' "$HERDR_LOG")" -eq 5 ] || { echo 'FAIL cockpit: expected 5 splits'; fail=1; }
cat > .claude/mobilities.json <<'EOT'
{"host":"orca","layout":"cockpit","panes":[{"type":"pilot","side":"top"}]}
EOT
expect orca-cockpit "$(ORCA_TERMINAL_HANDLE=t0 HERDR_ENV= bash "$BIN/open.sh")" "Orca cannot place panes left of or above the chat. Opening them on the right."
before=$(cat .claude/mobilities-todo.md)
bash "$BIN/todo.sh" --add ''
bash "$BIN/todo.sh" --add '   '
[ "$(cat .claude/mobilities-todo.md)" = "$before" ] && echo 'ok   todo-empty-add' || { echo 'FAIL todo-empty-add'; fail=1; }
printf '{"colors":{"heading":"#123abc"}}\n' > "$MOBILITIES_HOME/config.json"
[ "$(bash -c ". '$BIN/lib.sh'; color_value heading \"\$P_HEAD\"")" = '#123abc' ] && echo 'ok   shared-color' || { echo 'FAIL shared-color'; fail=1; }
cp .claude/mobilities.json "$REPO/keep.json"
mkdir -p "$REPO/alt" "$REPO/.mobilities"
printf '{"milestone":"from-alt","banner":true,"panes":[{"type":"ceo","sections":["links"]}]}\n' > "$REPO/alt/mobilities.json"
expect dir-env "$(MOBILITIES_DIR=alt bash -c ". '$BIN/lib.sh'; repo_dir; cfg .milestone")" "$REPO/alt" "from-alt"
expect dir-env-abs "$(MOBILITIES_DIR="$REPO/alt" bash -c ". '$BIN/lib.sh'; cfg .milestone")" "from-alt"
printf '{"milestone":"from-dot"}\n' > "$REPO/.mobilities/mobilities.json"
expect dir-dot "$(bash -c ". '$BIN/lib.sh'; cfg .milestone")" "from-dot"
rm -r "$REPO/.mobilities"
expect dir-claude "$(bash -c ". '$BIN/lib.sh'; repo_dir")" "$REPO/.claude"
printf -- '- [ ] alt item\n' > "$REPO/alt/mobilities-todo.md"
expect dir-todo "$(MOBILITIES_DIR=alt bash "$BIN/todo.sh" --once)" "☐ alt item"
expect dir-banner "$(MOBILITIES_DIR=alt CLAUDE_PROJECT_DIR="$REPO" bash "$BIN/banner.sh" | jq -r .systemMessage)" "LINKS"
mv "$REPO/keep.json" .claude/mobilities.json
printf '{}\n' > "$MOBILITIES_HOME/config.json"
expect heading-default "$(bash -c ". '$BIN/lib.sh'; heading_size")" "off"
printf '{"font":"standard"}\n' > "$MOBILITIES_HOME/config.json"
expect heading-old-font "$(bash -c ". '$BIN/lib.sh'; heading_size; heading_font big")" "big" "standard"
bash "$BIN/pilot.sh" --heading small
expect heading-set "$(jq -r .heading "$MOBILITIES_HOME/config.json")" "small"
bash "$BIN/pilot.sh" --cycle-heading
expect heading-cycle "$(jq -r .heading "$MOBILITIES_HOME/config.json")" "big"
bash "$BIN/pilot.sh" --cycle-heading
expect heading-cycle-off "$(jq -r .heading "$MOBILITIES_HOME/config.json")" "off"
bash "$BIN/pilot.sh" --heading huge 2>/dev/null && { echo 'FAIL heading-bad: accepted huge'; fail=1; }
expect theme-env "$(MOBILITIES_THEME=ocean bash -c ". '$BIN/lib.sh'; echo \$P_HEAD")" "bright-blue"
if command -v figlet >/dev/null 2>&1; then
  printf '{"heading":"big","fonts":{"big":"standard","small":"small"}}\n' > "$MOBILITIES_HOME/config.json"
  out=$(FZF_COLUMNS=200 bash -c ". '$BIN/lib.sh'; header ONE; header TWO")
  grep -qF -- '── ONE' <<<"$out" && { echo 'FAIL heading-big: ONE not big'; fail=1; }
  expect heading-first-only "$out" "── TWO"
  expect heading-narrow "$(FZF_COLUMNS=10 bash -c ". '$BIN/lib.sh'; header ONE")" "── ONE"
  expect heading-no-tty "$(bash -c ". '$BIN/lib.sh'; header ONE")" "── ONE"
  expect heading-env "$(MOBILITIES_HEADING=off FZF_COLUMNS=200 bash -c ". '$BIN/lib.sh'; header ONE")" "── ONE"
  expect heading-review "$(bash "$BIN/review.sh" 80)" "── PR #80"
fi
printf '{}\n' > "$MOBILITIES_HOME/config.json"
# later tasks append their checks above this line
exit $fail
