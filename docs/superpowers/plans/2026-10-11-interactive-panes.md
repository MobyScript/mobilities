# Interactive panes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every pane a clickable fzf list, add off/small/big headings and saved profiles, let the repo config live outside `.claude/` (issue #1), and fix the problems from the 2026-10-11 check.

**Architecture:** Every pane's `render` prints lines. A line that opens something is tagged `kind<TAB>id<TAB>text`; any other line is plain text. `lib.sh` turns that output into fzf rows (`--rows`) or plain text (`--once`, no fzf), and one `pick` function runs fzf for all panes. Heading size, profiles, and the config folder are small functions in `lib.sh` plus one new script, `profile.sh`. `preview.sh` opens a new host tab with one pane per style.

**Tech Stack:** bash, jq, fzf (0.59 or newer, for `--no-input`), figlet, gh, herdr or Orca CLI.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-11-interactive-panes-design.md`. Follow it where this plan is silent.
- Work only in the worktree `/Users/mobarkbacran/Desktop/Work/mobilities-interactive`, branch `feat/interactive-panes`. Do not push.
- Match the existing style: short bash, `set -uo pipefail` in pane scripts, comments only where the code is not obvious, `# ponytail:` comments for known shortcuts.
- No new dependencies. fzf, figlet, w3m stay optional: every pane must still work without them.
- Run `bash tests/run.sh` after every task. All checks must pass. New checks go above the line `# later tasks append their checks above this line`.
- `NO_COLOR=1` is set in tests, so color variables are empty there.
- Final version in `.claude-plugin/plugin.json`: `0.4.0`.

---

### Task 1: Configurable config folder (issue #1)

**Files:**
- Modify: `bin/lib.sh:1-7`
- Modify: `bin/todo.sh:5`, `bin/todo.sh:20` (message)
- Modify: `bin/banner.sh`
- Test: `tests/run.sh`

**Interfaces:**
- Produces: `repo_dir` (prints the absolute folder that holds `mobilities.json` and `mobilities-todo.md`), `HOMEDIR` (shared folder), `CFG` and `GCFG` as before.

- [ ] **Step 1: Write the failing tests** (append above the marker line in `tests/run.sh`)

```bash
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
```

- [ ] **Step 2: Run tests to see them fail**

Run: `bash tests/run.sh`
Expected: `FAIL dir-env` (no `repo_dir`), `FAIL dir-dot`, `FAIL dir-todo`, `FAIL dir-banner`.

- [ ] **Step 3: Implement**

Replace lines 4-6 of `bin/lib.sh` with:

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOMEDIR="${MOBILITIES_HOME:-$HOME/.config/mobilities}"
GCFG="$HOMEDIR/config.json"
# Repo files live in $MOBILITIES_DIR, else .mobilities/ if it has a config, else .claude/.
repo_dir() {
  if [ -n "${MOBILITIES_DIR:-}" ]; then
    case "$MOBILITIES_DIR" in /*) echo "$MOBILITIES_DIR";; *) echo "$ROOT/$MOBILITIES_DIR";; esac
  elif [ -f "$ROOT/.mobilities/mobilities.json" ]; then echo "$ROOT/.mobilities"
  else echo "$ROOT/.claude"; fi
}
CFG="$(repo_dir)/mobilities.json"
```

In `bin/todo.sh`, change line 5 to `F="$(repo_dir)/mobilities-todo.md"` and the "No todo file" message to print `"${F#$ROOT/}"` in place of the fixed `.claude/mobilities-todo.md`.

Replace `bin/banner.sh` with:

```bash
#!/usr/bin/env bash
# SessionStart hook: prints the CEO summary when the repo enables the banner.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
. "$HERE/lib.sh"
[ "$(cfg '.banner // false')" = true ] || exit 0
NO_COLOR=1 "$HERE/ceo.sh" --once 2>&1 | jq -Rs '{systemMessage: .}'
```

- [ ] **Step 4: Run tests**

Run: `bash tests/run.sh`
Expected: every line `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add bin/lib.sh bin/todo.sh bin/banner.sh tests/run.sh
git commit -m "feat: MOBILITIES_DIR and .mobilities/ for repo config (closes #1)"
```

---

### Task 2: Heading sizes, theme override, ocean fix

**Files:**
- Modify: `bin/lib.sh` (`theme`, `header`, new helpers, flag handling)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `HOMEDIR`, `GCFG`, `gcfg` from Task 1.
- Produces:
  - `tty_out` (true when stdout is a terminal or the script runs inside fzf, where `FZF_COLUMNS` is set).
  - `heading_size` prints `off|small|big`. `heading_font <small|big>` prints a figlet font name or path.
  - `set_heading <off|small|big>` writes `.heading` in the shared file.
  - Any script that sources `lib.sh "$@"` accepts `--cycle-heading` and `--heading <size>`, then exits.
  - `HEADED` is reset to 0 by `theme`. `header` uses figlet only when `HEADED=0`.
  - `MOBILITIES_HEADING` and `MOBILITIES_THEME` override the shared file.

- [ ] **Step 1: Write the failing tests** (above the marker)

```bash
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
```

- [ ] **Step 2: Run tests to see them fail**

Run: `bash tests/run.sh`
Expected: `FAIL heading-default` (no `heading_size`) and the other new checks fail.

- [ ] **Step 3: Implement**

In `bin/lib.sh`, after `gcfg()`, add:

```bash
tty_out() { [ -t 1 ] || [ -n "${FZF_COLUMNS:-}" ]; }
heading_size() {
  local s=${MOBILITIES_HEADING:-$(gcfg '.heading // empty')}
  [ -n "$s" ] || { [ -n "$(gcfg '.font // empty')" ] && s=big || s=off; }
  echo "$s"
}
heading_font() { # heading_font <small|big>
  if [ "$1" = small ]; then gcfg ".fonts.small // \"$HOMEDIR/fonts/pagga.tlf\""
  else gcfg ".fonts.big // .font // \"$HOMEDIR/fonts/ansi-shadow.flf\""; fi
}
set_heading() {
  mkdir -p "$HOMEDIR"; [ -f "$GCFG" ] || echo '{}' > "$GCFG"
  jq --arg h "$1" '.heading = $h' "$GCFG" > "$GCFG.tmp" && mv "$GCFG.tmp" "$GCFG"
}
case "${1:-}" in
  --cycle-heading) case "$(heading_size)" in off) set_heading small;; small) set_heading big;; *) set_heading off;; esac; exit 0;;
  --heading) [[ "${2:-}" =~ ^(off|small|big)$ ]] || { echo 'Use off, small, or big.' >&2; exit 1; }; set_heading "$2"; exit 0;;
esac
```

In `theme()`:
- First line becomes `case "${MOBILITIES_THEME:-$(gcfg '.theme // "default"')}" in`.
- The ocean line becomes `ocean)  P_HEAD=bright-blue; P_DONE=cyan; P_WARN=yellow; P_ERR=magenta;;`.
- The color condition becomes `if tty_out && [ -z "${NO_COLOR:-}" ]; then`.
- Add `HEADED=0` as the last line of the function.

Replace `header()` with:

```bash
# width <text>: the widest line, counted in characters, not bytes.
width() ( LC_ALL=en_US.UTF-8; m=0; while IFS= read -r l; do [ "${#l}" -gt "$m" ] && m=${#l}; done <<<"$1"; echo "$m" )
# Only the first heading of a render may be big, and only if it fits.
header() {
  local size font out l
  size=$(heading_size)
  if [ "$HEADED" = 0 ] && [ "$size" != off ] && tty_out && command -v figlet >/dev/null 2>&1 &&
     font=$(heading_font "$size") && out=$(figlet -w 999 -f "$font" "$1" 2>/dev/null) && [ -n "$out" ] &&
     [ "$(width "$out")" -le "${FZF_COLUMNS:-$(tput cols 2>/dev/null || echo 80)}" ]; then
    HEADED=1
    while IFS= read -r l; do printf '%s%s%s%s\n' "$BOLD" "$HEAD" "$l" "$RST"; done <<<"$out"
    return
  fi
  HEADED=1; printf '%s%s── %s %s\n' "$BOLD" "$HEAD" "$1" "$RST"
}
```

Make sure that the flag `case` block sits after `gcfg` and the new helpers, and before `theme` is called.

- [ ] **Step 4: Run tests**

Run: `bash tests/run.sh`
Expected: all `ok`, exit 0. If `width` counts bytes on Linux (no `en_US.UTF-8`), use `C.UTF-8` as a fallback: `LC_ALL=$(locale -a 2>/dev/null | grep -im1 -E '^(en_US|C)\.utf-?8$' || echo C)`.

- [ ] **Step 5: Commit**

```bash
git add bin/lib.sh tests/run.sh
git commit -m "feat: off/small/big headings that fit the pane"
```

---

### Task 3: Row engine and clickable Pilot, CEO, Activity

**Files:**
- Modify: `bin/lib.sh` (replace `loop` with `run_pane`; add `to_rows`, `plain`, `pick`, `open_row`, `nav_keys`, `SELF`, `ROWS`)
- Modify: `bin/pilot.sh`, `bin/ceo.sh`, `bin/activity.sh`
- Create: `tests/fakes/fzf`, `tests/fakes/less`, `tests/fakes/w3m`
- Modify: `tests/fakes/gh` (add `pr checks`)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `header`, `theme`, `tty_out` from Task 2.
- Produces:
  - Row format: `kind<TAB>id<TAB>text`. Kinds: `pr`, `issue`, `commit`, `link`, `todo`. A line with fewer than two tabs is a plain line.
  - `run_pane <seconds> <render-fn> [fzf args...]`: `--rows` prints rows and exits; `--once` or no fzf prints plain text (once or in a loop); otherwise calls `pick`.
  - `pick <seconds> [fzf args...]`: runs fzf on `$SELF --rows`, with live reload, Enter and double-click bound to `$SELF --open {1} {2}`, ctrl-r reload, alt-f heading cycle. Caller args come last and override these binds.
  - `open_row <kind> <id>`; any pane script accepts `--open <kind> <id>`.
  - `SELF`: the running script, quoted with `%q`.
  - `nav_keys`: bash array of fzf args for panes with no search box.
  - `MOBILITIES_PREVIEW`: if set, its text is the first line of the pane.

- [ ] **Step 1: Add the fakes**

`tests/fakes/fzf`:

```bash
#!/usr/bin/env bash
# Fake fzf: logs its arguments, one per line.
printf '%s\n' "$@" >> "${FZF_LOG:-/dev/null}"
```

`tests/fakes/less`:

```bash
#!/usr/bin/env bash
# Fake less: prints its input.
cat
```

`tests/fakes/w3m`:

```bash
#!/usr/bin/env bash
echo "w3m $*"
```

Run `chmod +x tests/fakes/fzf tests/fakes/less tests/fakes/w3m`. In `tests/fakes/gh`, add above the `*)` line:

```bash
  "pr checks"*)                       echo 'test	pass';;
```

- [ ] **Step 2: Write the failing tests** (above the marker)

```bash
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m 'first commit'
sha=$(git rev-parse HEAD)
expect rows-pilot "$(FZF_COLUMNS=200 bash "$BIN/pilot.sh" --rows)" $'pr\t80\t' $'\t\t── PILOT'
expect rows-ceo "$(FZF_COLUMNS=200 bash "$BIN/ceo.sh" --rows)" $'pr\t80\t' $'issue\t7\t' $'link\thttps://github.com/acme/app/wiki\t'
expect rows-activity "$(FZF_COLUMNS=200 bash "$BIN/activity.sh" --rows)" $'commit\tabc1234def\t' $'pr\t68\t' $'issue\t90\t'
expect rows-plain "$(bash "$BIN/ceo.sh" --once)" "#7  Fix login"
grep -q $'\t' <<<"$(bash "$BIN/ceo.sh" --once)" && { echo 'FAIL rows-plain: tab in plain output'; fail=1; }
expect open-pr "$(bash "$BIN/pilot.sh" --open pr 80)" "test"
expect open-issue "$(bash "$BIN/pilot.sh" --open issue 50)" "US-2-1"
expect open-commit "$(bash "$BIN/pilot.sh" --open commit "$sha")" "first commit"
expect open-link "$(bash "$BIN/pilot.sh" --open link https://example.com)" "w3m https://example.com"
[ -z "$(bash "$BIN/pilot.sh" --open pr '1;rm')" ] && echo 'ok   open-bad-id' || { echo 'FAIL open-bad-id'; fail=1; }
expect preview-label "$(MOBILITIES_PREVIEW='Big font' bash "$BIN/pilot.sh" --once)" "Big font"
export FZF_LOG="$(mktemp)"
bash "$BIN/pilot.sh" </dev/null >/dev/null
expect pick-nav "$(cat "$FZF_LOG")" "--no-input" "--with-nth" "3.." "--layout=reverse" "double-click:execute(" "--open {1} {2})" "f:execute-silent(" "--cycle-heading" "r:reload("
git checkout -q --detach
expect pilot-detached "$(bash "$BIN/pilot.sh" --once)" "detached ${sha:0:7}"
git checkout -q -
```

- [ ] **Step 3: Run tests to see them fail**

Run: `bash tests/run.sh`
Expected: `FAIL rows-pilot` and the other new checks fail.

- [ ] **Step 4: Implement `lib.sh`**

Replace the `ONCE=...` line with:

```bash
ONCE=0 ROWS=0; for a in "$@"; do case "$a" in --once) ONCE=1;; --rows) ROWS=1;; esac; done
printf -v SELF '%q' "$0"
```

Add `open_row` before the flag `case` block, and add an `--open` branch to that block:

```bash
open_row() { # open_row <kind> <id>: shows the details in the terminal.
  case "$1:$2" in
    pr:*)     [[ "$2" =~ ^[0-9]+$ ]] && { gh pr view "$2" --comments; gh pr checks "$2"; } 2>&1 | less -R;;
    issue:*)  [[ "$2" =~ ^[0-9]+$ ]] && gh issue view "$2" --comments 2>&1 | less -R;;
    commit:*) [[ "$2" =~ ^[0-9a-f]+$ ]] && git -C "$ROOT" show --color=always "$2" | less -R;;
    link:*)   [[ "$2" =~ ^https?:// ]] && { if command -v w3m >/dev/null 2>&1; then w3m "$2"; else open "$2"; fi; };;
  esac
  return 0
}
```

```bash
  --open) open_row "${2:-}" "${3:-}"; exit 0;;
```

Replace `loop()` with:

```bash
to_rows() { awk -F'\t' 'NF >= 3 { print; next } { print "\t\t" $0 }'; }
plain()   { awk -F'\t' 'NF >= 3 { sub(/^[^\t]*\t[^\t]*\t/, "") } { print }'; }
paint()   { [ -z "${MOBILITIES_PREVIEW:-}" ] || printf '%s%s%s\n' "$DIM" "$MOBILITIES_PREVIEW" "$RST"; "$1"; }
nav_keys=(--no-input --header 'enter open · f size · r reload'
  --bind "f:execute-silent($SELF --cycle-heading)+reload($SELF --rows)" --bind "r:reload($SELF --rows)")
pick() { # pick <reload-seconds> [fzf args...]
  local secs=$1 list="$SELF --rows" portfile watcher; shift
  portfile=$(mktemp)
  # ponytail: curl ships with macOS; ctrl-r still reloads if the timer fails.
  ( while [ ! -s "$portfile" ]; do sleep 0.1; done
    while sleep "$secs"; do curl -fsS -X POST "http://127.0.0.1:$(cat "$portfile")" -d "reload($list)" >/dev/null 2>&1 || :; done ) & watcher=$!
  fzf --ansi --listen 0 --layout=reverse --no-sort --delimiter $'\t' --with-nth 3.. \
    --bind "start:execute-silent(printf %s \"\$FZF_PORT\" > '$portfile')+reload($list)" \
    --bind "enter:execute($SELF --open {1} {2})" --bind "double-click:execute($SELF --open {1} {2})" \
    --bind "ctrl-r:reload($list)" --bind "alt-f:execute-silent($SELF --cycle-heading)+reload($list)" \
    "$@" </dev/null >/dev/null
  kill "$watcher" 2>/dev/null || :; rm -f "$portfile"
}
run_pane() { # run_pane <seconds> <render-fn> [fzf args...]
  local secs=$1 fn=$2; shift 2
  if [ "$ROWS" = 1 ]; then paint "$fn" | to_rows; exit 0; fi
  if [ "$ONCE" = 0 ] && command -v fzf >/dev/null 2>&1; then pick "$secs" "$@"; exit 0; fi
  if [ "$ONCE" = 1 ]; then theme; paint "$fn" | plain; exit 0; fi
  while true; do theme; clear; paint "$fn" | plain; sleep "$secs"; done
}
```

- [ ] **Step 5: Implement the panes**

`bin/pilot.sh`:
- Branch line: `branch=$(git branch --show-current); [ -n "$branch" ] || branch="detached $(git rev-parse --short HEAD 2>/dev/null)"`.
- The PR jq filter ends in `"pr\t\(.number)\t  PR #\(.number)  \(.title[0:40]) · ..."` (the same text as now, with the `pr\t<n>\t` prefix).
- Last line: `run_pane 60 render "${nav_keys[@]}"`.

`bin/ceo.sh`:
- Epics: add `.number` as the first `@tsv` field, read it as `n`, and print `printf 'issue\t%s\t  %s ' "$num" "$title"; bar "$d" "$t"; echo`. Rename the loop variable so it does not clash with the jq `$n` capture.
- Review queue: `printf 'pr\t%s\t  %s#%s%s  %-48s %s(%s)%s\n' "$n" "$WARN" "$n" "$RST" "$t" "$DIM" "$a" "$RST"`.
- Assigned: jq `"issue\t\(.number)\t  #\(.number)  \(.title)"`.
- Links: `printf 'link\t%s\t  %sissues%s %s\n' "https://github.com/$REPO/issues" "$DIM" "$RST" "https://github.com/$REPO/issues"` and `cfg '.links // {} | to_entries[] | "link\t\(.value)\t  \(.key) \(.value)"'`.
- Last line: `run_pane 600 render "${nav_keys[@]}"`.

`bin/activity.sh`, replace `render`, `show`, and the last line with:

```bash
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
```

`bin/todo.sh` and `bin/prs.sh` still call `loop`. Leave a one-line shim in `lib.sh` until Task 4: `loop() { run_pane "$1" "$2"; }`. Task 4 deletes it.

- [ ] **Step 6: Run tests**

Run: `bash tests/run.sh`
Expected: all `ok`, exit 0. Existing checks `ceo`, `activity`, `pilot`, `banner` must still pass, because they read plain output.

- [ ] **Step 7: Commit**

```bash
git add bin/lib.sh bin/pilot.sh bin/ceo.sh bin/activity.sh tests/fakes tests/run.sh
git commit -m "feat: clickable Pilot, CEO, and Activity panes"
```

---

### Task 4: Todo and PR watch on the shared picker

**Files:**
- Modify: `bin/todo.sh`, `bin/prs.sh`, `bin/lib.sh` (delete the `loop` shim)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `run_pane`, `pick`, `SELF`, row format from Task 3. `repo_dir` from Task 1.
- Produces: `todo.sh` rows `todo<TAB><line number><TAB>text`; `prs.sh` rows `pr<TAB><number><TAB>text`. `--list` is removed from both scripts.

- [ ] **Step 1: Write the failing tests** (above the marker)

```bash
printf '# Week\n- [ ] First\n- [x] Second\n' > .claude/mobilities-todo.md
out=$(FZF_COLUMNS=200 bash "$BIN/todo.sh" --rows)
expect rows-todo "$out" $'todo\t2\t  ☐ First' $'todo\t3\t  ✓ Second' $'\t\tWeek'
[ "$(grep -n First <<<"$out" | cut -d: -f1)" -lt "$(grep -n Second <<<"$out" | cut -d: -f1)" ] && echo 'ok   todo-order' || { echo 'FAIL todo-order'; fail=1; }
: > "$FZF_LOG"; bash "$BIN/todo.sh" </dev/null >/dev/null
expect pick-todo "$(cat "$FZF_LOG")" "+clear-query+" "--toggle {2}" "--delete {2}" "double-click:execute-silent("
expect rows-prs "$(FZF_COLUMNS=200 bash "$BIN/prs.sh" --rows)" $'pr\t81\t' $'pr\t82\t' "CI failed: test"
: > "$FZF_LOG"; bash "$BIN/prs.sh" </dev/null >/dev/null
expect pick-prs "$(cat "$FZF_LOG")" "<80(hidden)" "gh pr diff {2}"
```

- [ ] **Step 2: Run tests to see them fail**

Run: `bash tests/run.sh`
Expected: `FAIL rows-todo`, `FAIL pick-todo`, `FAIL rows-prs`, `FAIL pick-prs`.

- [ ] **Step 3: Implement `todo.sh`**

Delete the `--list` branch. Replace `render` and everything after it with:

```bash
render() {
  header "TODO"
  [ -f "$F" ] || { printf '  %sNo todo file. Create %s or ask Claude to add items.%s\n' "$DIM" "${F#$ROOT/}" "$RST"; return; }
  awk -v b="$BOLD" -v d="$DIM" -v g="$DONE" -v r="$RST" '
    /^# /           { sub(/^# /, "");           print b $0 r; next }
    /^- \[[xX]\] /  { sub(/^- \[[xX]\] /, "");  print "todo\t" NR "\t  " d g "✓ " $0 r; next }
    /^- \[ \] /     { sub(/^- \[ \] /, "");     print "todo\t" NR "\t  " b "☐ " $0 r; next }
    { gsub(/\t/, " "); print }' "$F"
}
toggle="execute-silent($SELF --toggle {2})+reload($SELF --rows)"
run_pane 5 render --header 'enter toggle · alt-enter add · ctrl-d delete · alt-f size' \
  --bind "enter:$toggle" --bind "double-click:$toggle" \
  --bind "alt-enter:execute-silent($SELF --add {q})+clear-query+reload($SELF --rows)" \
  --bind "ctrl-d:execute-silent($SELF --delete {2})+reload($SELF --rows)"
```

The existing `--toggle` and `--delete` reject an empty or non-number id, so Enter on a heading row does nothing.

- [ ] **Step 4: Implement `prs.sh`**

Replace everything after `need_repo` with:

```bash
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
run_pane 120 render --header 'enter diff · ctrl-r reload · alt-f size' \
  --preview '[ {1} = pr ] && gh pr view {2} && gh pr checks {2}' --preview-window 'right,50%,<80(hidden)' \
  --bind "enter:$diff" --bind "double-click:$diff"
```

Delete the `loop()` shim from `lib.sh`.

- [ ] **Step 5: Run tests**

Run: `bash tests/run.sh`
Expected: all `ok`, exit 0. The old checks `todo`, `prs`, `todo-toggle`, `todo-add`, `todo-delete`, `todo-empty-add` still pass.

- [ ] **Step 6: Commit**

```bash
git add bin/todo.sh bin/prs.sh bin/lib.sh tests/run.sh
git commit -m "feat: todo and PR watch on the shared picker, with fixes"
```

---

### Task 5: Profiles, style preview, quiet swaps

**Files:**
- Create: `bin/profile.sh`, `bin/preview.sh`
- Modify: `bin/lib.sh` (add `pane_host`, `orca_place`), `bin/open.sh`
- Modify: `tests/fakes/herdr`, `tests/fakes/orca` (tab create and terminal create replies)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `repo_dir`, `GCFG`, `CFG`, `set_heading` (Tasks 1-2).
- Produces:
  - `pane_host`: prints `orca` or `herdr`; returns 2 with the "Open this project in Orca..." message on stderr when no host runs this session.
  - `orca_place <handle> <command...>`: `<handle>` already runs the first command; splits the rest in a balanced way (the current `place` logic in `open.sh`, but over commands).
  - `profile.sh save <name>`, `profile.sh apply <name>`, `profile.sh list`, `profile.sh heading <off|small|big>`.
  - `preview.sh fonts|themes`: opens a new host tab and prints `Close with: <command>` on the last line.

Real CLI replies (checked on this machine):
- `herdr tab create --label X --cwd D --focus` prints `{"result":{"tab":{"tab_id":"w9:t6",...},"root_pane":{"pane_id":"w9:pP",...}}}`. Close with `herdr tab close <tab_id>`.
- `orca terminal create --title X --command C --focus --json` prints `{"result":{"terminal":{"handle":"term_...",...}}}`. Close with `orca terminal close --terminal <handle> --tab`.

- [ ] **Step 1: Update the fakes**

`tests/fakes/herdr`, replace the `case` line:

```bash
case "$*" in
  "pane split"*) echo "{\"result\":{\"pane\":{\"pane_id\":\"p$RANDOM\"}}}";;
  "pane swap"*)  echo '{"result":{"type":"ok"}}';;
  "tab create"*) echo '{"result":{"tab":{"tab_id":"t9"},"root_pane":{"pane_id":"p9"}}}';;
esac
```

`tests/fakes/orca`, replace the `case` line:

```bash
case "$*" in
  "terminal split"*)  echo "{\"result\":{\"split\":{\"handle\":\"t$RANDOM\"}}}";;
  "terminal create"*) echo '{"result":{"terminal":{"handle":"tc"}}}';;
esac
```

- [ ] **Step 2: Write the failing tests** (above the marker)

```bash
printf '{"theme":"ocean","heading":"small","colors":{},"fonts":{"small":"small"},"role":"developer","layout":"cockpit","panes":[{"type":"pilot"}]}\n' > "$MOBILITIES_HOME/config.json"
bash "$BIN/profile.sh" save work
expect profile-save "$(jq -c '.profiles.work | {theme, heading, layout}' "$MOBILITIES_HOME/config.json")" '{"theme":"ocean","heading":"small","layout":"cockpit"}'
jq '.theme="mono" | .heading="off"' "$MOBILITIES_HOME/config.json" > "$MOBILITIES_HOME/c.tmp" && mv "$MOBILITIES_HOME/c.tmp" "$MOBILITIES_HOME/config.json"
cp .claude/mobilities.json "$REPO/keep.json"
bash "$BIN/profile.sh" apply work
expect profile-apply "$(jq -c '{theme, heading}' "$MOBILITIES_HOME/config.json")" '{"theme":"ocean","heading":"small"}'
expect profile-apply-repo "$(jq -c '{role, layout, panes}' .claude/mobilities.json)" '"layout":"cockpit"' '"type":"pilot"'
expect profile-list "$(bash "$BIN/profile.sh" list)" "work"
bash "$BIN/profile.sh" apply nope 2>/dev/null && { echo 'FAIL profile-missing: accepted'; fail=1; }
mv "$REPO/keep.json" .claude/mobilities.json
: > "$HERDR_LOG"
out=$(ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/preview.sh" fonts)
expect preview-herdr "$(cat "$HERDR_LOG")" "tab create" "MOBILITIES_HEADING=off" "MOBILITIES_HEADING=small" "MOBILITIES_HEADING=big" "pilot.sh"
expect preview-close "$out" "Close with: herdr tab close t9"
: > "$ORCA_LOG"
out=$(ORCA_TERMINAL_HANDLE=t0 HERDR_ENV= bash "$BIN/preview.sh" themes)
expect preview-orca "$(cat "$ORCA_LOG")" "terminal create" "MOBILITIES_THEME=ocean" "MOBILITIES_THEME=mono"
expect preview-orca-close "$out" "Close with: orca terminal close --terminal tc --tab"
cp .claude/mobilities.json "$REPO/keep.json"
cat > .claude/mobilities.json <<'EOT'
{"host":"herdr","layout":"cockpit","panes":[{"type":"pilot","side":"top"},{"type":"todo","side":"left"}]}
EOT
out=$(ORCA_TERMINAL_HANDLE= HERDR_ENV=1 HERDR_PANE_ID=p0 bash "$BIN/open.sh")
grep -q '"result"' <<<"$out" && { echo 'FAIL swap-quiet: JSON printed'; fail=1; } || echo 'ok   swap-quiet'
mv "$REPO/keep.json" .claude/mobilities.json
```

- [ ] **Step 3: Run tests to see them fail**

Run: `bash tests/run.sh`
Expected: `FAIL profile-save`, `FAIL preview-herdr`, `FAIL preview-orca`, `FAIL swap-quiet`.

- [ ] **Step 4: Move host code into `lib.sh`**

Add to `bin/lib.sh`:

```bash
pane_host() {
  local h; h=$(cfg '.host // empty')
  if [ -z "$h" ]; then
    if [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; then h=orca; elif [ "${HERDR_ENV:-}" = 1 ]; then h=herdr; fi
  fi
  if { [ "$h" = orca ] && [ -n "${ORCA_TERMINAL_HANDLE:-}" ]; } || { [ "$h" = herdr ] && [ "${HERDR_ENV:-}" = 1 ]; }; then echo "$h"; return 0; fi
  echo 'Open this project in Orca (https://orca.build) or herdr (https://herdr.dev), start Claude Code there, and run /mobilities again.' >&2
  return 2
}
# orca_place <handle> <command...>: <handle> already runs the first command.
orca_place() {
  local h=$1; shift; local n=$# k=$(( $# / 2 ))
  [ "$n" -le 1 ] && return
  [ "$k" -eq 0 ] && k=1
  local rest=("${@:k+1}") new
  new=$(orca terminal split --terminal "$h" --direction horizontal --command "${rest[0]}" --json | jq -r '.result.split.handle')
  orca_place "$h" "${@:1:k}"
  orca_place "$new" "${rest[@]}"
}
```

In `bin/open.sh`:
- Replace the first `host=...` block and the guard (lines 5-10) with `host=$(pane_host) || exit 2`.
- In the Orca branch, delete `cmd()` and `place()`, build `cmds=(); for i in "${indexes[@]}"; do cmds+=("cd '$ROOT' && $(pane_cmd "$i")"); done`, split the root with `--command "${cmds[0]}"`, then call `orca_place "$root" "${cmds[@]}"`.
- Add `>/dev/null` after both `herdr pane swap --source-pane "$chat" --target-pane "$new"` calls.

The `open-guard` check reads `2>&1`, so the message on stderr still passes.

- [ ] **Step 5: Write `bin/profile.sh`**

```bash
#!/usr/bin/env bash
# Saves and applies named profiles: look and layout, kept in the shared config.json.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
mkdir -p "$HOMEDIR"; [ -f "$GCFG" ] || echo '{}' > "$GCFG"
look='{role, layout, panes, theme, colors, heading, fonts} | with_entries(select(.value != null))'
write() { jq "$@" "$GCFG" > "$GCFG.tmp" && mv "$GCFG.tmp" "$GCFG"; }
case "${1:-}:${2:-}" in
  save:?*)  write --arg n "$2" ".profiles[\$n] = ($look)";;
  apply:?*)
    p=$(jq -e --arg n "$2" '.profiles[$n]' "$GCFG") || { echo "No profile named $2." >&2; exit 1; }
    write --argjson p "$p" '. + ($p | del(.role, .layout, .panes))'
    mkdir -p "$(dirname "$CFG")"; [ -f "$CFG" ] || echo '{}' > "$CFG"
    jq --argjson p "$p" '. + ($p | {role, layout, panes} | with_entries(select(.value != null)))' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG";;
  list:*)   jq -r '.profiles // {} | keys[]' "$GCFG";;
  heading:*) exec "$BIN/pilot.sh" --heading "${2:-}";;
  *) echo 'Use: profile.sh save <name> | apply <name> | list | heading <off|small|big>' >&2; exit 1;;
esac
```

Note: `pilot.sh --heading` exits in `lib.sh` before `need_repo`, so it works outside a GitHub repo. Run `chmod +x bin/profile.sh`.

- [ ] **Step 6: Write `bin/preview.sh`**

```bash
#!/usr/bin/env bash
# Opens a new tab with one live Pilot pane per style: preview.sh fonts|themes
set -euo pipefail
. "$(dirname "$0")/lib.sh"
host=$(pane_host) || exit 2
case "${1:-}" in
  fonts)  var=MOBILITIES_HEADING; opts=(off small big);;
  themes) var=MOBILITIES_THEME;   opts=(default dark light ocean sunset mono);;
  *) echo 'Use: preview.sh fonts|themes' >&2; exit 1;;
esac
cmds=(); for o in "${opts[@]}"; do cmds+=("cd '$ROOT' && MOBILITIES_PREVIEW='$o' $var=$o '$BIN/pilot.sh'"); done
if [ "$host" = herdr ]; then
  tab=$(herdr tab create --label 'mobilities preview' --cwd "$ROOT" --focus)
  prev=$(jq -r '.result.root_pane.pane_id' <<<"$tab")
  herdr pane run "$prev" "${cmds[0]}"
  # --ratio is the share the split pane keeps, so each pane gets an equal width.
  for ((i=1; i<${#cmds[@]}; i++)); do
    ratio=$(awk "BEGIN { print 1 / (${#cmds[@]} - $i + 1) }")
    prev=$(herdr pane split --pane "$prev" --direction right --ratio "$ratio" --cwd "$ROOT" --no-focus | jq -r '.result.pane.pane_id')
    herdr pane run "$prev" "${cmds[i]}"
  done
  echo "Close with: herdr tab close $(jq -r '.result.tab.tab_id' <<<"$tab")"
else
  h=$(orca terminal create --title 'mobilities preview' --command "${cmds[0]}" --focus --json | jq -r '.result.terminal.handle')
  orca_place "$h" "${cmds[@]}"
  echo "Close with: orca terminal close --terminal $h --tab"
fi
```

Each split keeps 1/(n-i+1) of the remaining width for the pane on the left, so the first split leaves the root pane 1/n and all panes end up equal. Run `chmod +x bin/preview.sh`.

- [ ] **Step 7: Run tests**

Run: `bash tests/run.sh`
Expected: all `ok`, exit 0, including the old `open-*`, `orca-layout`, `cockpit`, and `orca-cockpit` checks.

- [ ] **Step 8: Commit**

```bash
git add bin/lib.sh bin/open.sh bin/profile.sh bin/preview.sh tests/fakes tests/run.sh
git commit -m "feat: profiles, style preview tabs, quiet herdr swaps"
```

---

### Task 6: Skill, README, version

**Files:**
- Modify: `skills/mobilities/SKILL.md`, `README.md`, `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: every script interface above.

- [ ] **Step 1: Update `SKILL.md`**

1. Arguments: change the "Empty" line to "if `mobilities.json` exists in the repo config folder (`$MOBILITIES_DIR`, else `.mobilities/`, else `.claude/`)". Add:
   - `font <off|small|big>`: run `bin/profile.sh heading <size>`. The panes change on their next reload.
   - `profile <name>`: run `bin/profile.sh apply <name>`, then tell the user to close the panes and run `/mobilities`.
   - `profile save <name>`: run `bin/profile.sh save <name>`.
2. Step 1 of Onboarding: also run `bin/profile.sh list`.
3. Tab group 1, question 1: if profiles exist, list each profile name plus "Start a new one". If the user picks a profile, run `bin/profile.sh apply <name>`, then skip tab group 2 and the role, host, and layout questions.
4. Tab group 2 (the look): before the theme question, run `bin/preview.sh themes` and tell the user to look at the new tab. Ask "Is your terminal light or dark?" and the theme in one call. Run the `Close with:` command from the output. Then download the fonts if they are missing:

   ```bash
   mkdir -p ~/.config/mobilities/fonts
   [ -f ~/.config/mobilities/fonts/pagga.tlf ] || curl -fsSL -o ~/.config/mobilities/fonts/pagga.tlf https://raw.githubusercontent.com/xero/figlet-fonts/master/pagga.tlf
   [ -f ~/.config/mobilities/fonts/ansi-shadow.flf ] || curl -fsSL -o ~/.config/mobilities/fonts/ansi-shadow.flf "https://raw.githubusercontent.com/xero/figlet-fonts/master/ANSI%20Shadow.flf"
   ```

   Run `bin/preview.sh fonts`. Ask "Heading size?" (off, small, big) and "Banner on or off?" in one call. Close the preview. The heading answer is saved as `heading`.
5. Last question: "Save this as a profile?" with the name `default` first. Run `bin/profile.sh save <name>` after the configuration is written.
6. Write the configuration: the repo file goes to `$MOBILITIES_DIR` if set, else the folder of an existing `mobilities.json`, else `.claude/`. Append that folder's `mobilities.json` and `mobilities-todo.md` paths to `.gitignore`. Shared file keys: `role`, `layout`, `panes`, `theme`, `colors`, `heading`, `fonts`. Drop the old `font` key from the instructions.
7. Colors, question 5: replace it with the heading size question, and point to `bin/preview.sh fonts`.
8. Interactive panes section: every pane is a list. Click selects, double-click or Enter opens the details in the pane, q goes back. Pilot, CEO, and Activity: f heading size, r reload. Todo: Enter toggles, alt-enter adds, ctrl-d deletes, alt-f size. PR watch: Enter shows the diff, ctrl-r reloads, alt-f size. Needs fzf 0.59 or newer.

- [ ] **Step 2: Update `README.md`**

Use plain English (short sentences, active voice, no em dashes). Change:
1. "Colors and fonts": the three heading sizes, the f key, `/mobilities font`, and the fonts folder.
2. A new "Profiles" section: what a profile holds, `/mobilities profile save <name>` and `/mobilities profile <name>`.
3. A new "Where the files live" section: `MOBILITIES_DIR`, then `.mobilities/`, then `.claude/` for the repo files, and `MOBILITIES_HOME` (default `~/.config/mobilities`) for the shared file. Say that this lets other harnesses use the plugin (issue #1).
4. The interactive panes section: the keys from Step 1 item 8.
5. The configuration example: replace `"font": "small"` with `"heading": "small"`.
6. Every fixed `.claude/mobilities.json` or `.claude/mobilities-todo.md` path: say "in the repo config folder" where the path is general.

- [ ] **Step 3: Raise the version**

In `.claude-plugin/plugin.json`, change `"version": "0.3.0"` to `"version": "0.4.0"`.

- [ ] **Step 4: Run tests and validate**

Run: `bash tests/run.sh && claude plugin validate .`
Expected: all `ok`, exit 0, and the validator passes.

- [ ] **Step 5: Commit**

```bash
git add skills/mobilities/SKILL.md README.md .claude-plugin/plugin.json
git commit -m "docs: profiles, heading sizes, config folder; version 0.4.0"
```

---

## After the tasks (Claude, not Codex)

1. Review the full diff: `git diff origin/main...HEAD`.
2. Open the new panes from the worktree in a herdr tab against the real repo, and run `bin/preview.sh fonts` and `bin/preview.sh themes`. The user clicks through them.
3. Push and open the PR only after the user approves. The PR description says "Closes #1".
