---
name: mobilities
description: Open live GitHub project panes (CEO, Todo, PR watch, Activity) in herdr next to Claude Code. Runs onboarding the first time in a repo. Use for /mobilities, /mobilities setup, /mobilities review <PR#>, or when the user asks to open, set up, or change their project dashboard panes.
---

# mobilities

Scripts live at `<this skill's base directory>/../../bin/`. Call them by absolute path.

## Arguments

- Empty: if `.claude/mobilities.json` exists in the repo root, run `bin/open.sh` and report what opened. Otherwise run Onboarding.
- `setup`: run Onboarding.
- `review <N>`: run `bin/review.sh <N>` and show the output. Then run `gh pr diff <N>` and review the diff for correctness and security against the linked issue's acceptance criteria. Report findings, most severe first.

## Onboarding

Ask with AskUserQuestion, ONE question per message, in this order. Skip a question when its answer is already known.

1. Run `command -v herdr`. If missing, offer `brew install herdr` (macOS) or point to https://herdr.dev. Also check `gh auth status` and `jq`.
2. If `${MOBILITIES_HOME:-~/.config/mobilities}/config.json` exists, ask: "Use the same panes as your other projects, or make a new layout?" If reuse, skip to question 5.
3. "Default layout (CEO, Todo, PR watch, Activity) or your own?"
4. Own layout: how many panes (1-6), the type of each (`ceo`, `todo`, `prs`, `activity`), and for CEO which sections (`epics`, `reviews`, `assigned`, `milestone`, `links`; multiSelect).
5. Colors: presets `default`, `ocean`, `sunset`, `mono`, or custom names (black, red, green, yellow, blue, magenta, cyan, white, bright-*) for heading, done, warning, error.
6. Epics and stories: run `gh issue list --state all --limit 100 --json title,labels`. Infer the epic label and title regex (named group `n`) and the story label and title template (`{n}`). Ask the user to accept or edit. If no epics exist, omit `epics` from the CEO sections.
7. Deadline: list titles from `gh api repos/{owner}/{repo}/milestones` plus "type a date" and "no deadline".
8. Banner on or off (default off).

## Write the configuration

Build JSON with `jq -n`; never hand-write it.

- Repo file `.claude/mobilities.json`: `panes`, `epics`, `stories`, `milestone`, `links`, `banner`.
- Shared file `${MOBILITIES_HOME:-~/.config/mobilities}/config.json`: `theme`, `colors`, `layout`.

Append `.claude/mobilities.json` and `.claude/mobilities-todo.md` to `.gitignore` if absent. Then run `bin/open.sh`.

## herdr not running

If `open.sh` exits 2, tell the user its message. Do not try to start herdr from inside Claude Code.

## Todo

When the user asks to add or tick todos, edit `.claude/mobilities-todo.md` (`- [ ]` open, `- [x]` done).
