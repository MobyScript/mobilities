---
name: mobilities
description: Open live GitHub project panes (CEO, Todo, PR watch, Activity) and terminal tool panes (lazygit, gh dash, glow, w3m) in Orca or herdr next to Claude Code. Runs onboarding the first time in a repo. Use for /mobilities, /mobilities setup, /mobilities add, /mobilities colors, /mobilities review <PR#>, or when the user asks to open, add, recolor, or change their project dashboard panes.
---

# mobilities

Scripts live at `<this skill's base directory>/../../bin/`. Call them by absolute path.

## Arguments

- Empty: if `.claude/mobilities.json` exists in the repo root, run `bin/open.sh` and report what opened. Otherwise run Onboarding.
- `setup`: run Onboarding.
- `add`: run Add a pane.
- `colors`: run Colors.
- `review <N>`: run `bin/review.sh <N>` and show the output. Then run `gh pr diff <N>` and review the diff for correctness and security against the linked issue's acceptance criteria. Report findings, most severe first.

## Onboarding

Ask with AskUserQuestion, ONE question per message, in this order. Skip a question when its answer is already known.

1. Tools: run `gh auth status` and check `jq`. For pane hosts, run `command -v orca` and `command -v herdr`. If neither is installed, recommend Orca (https://orca.build) and offer herdr (https://herdr.dev, `brew install herdr`) as the alternative.
2. If `${MOBILITIES_HOME:-~/.config/mobilities}/config.json` exists, the user set up mobilities in another project before. Show its `role` and pane types, then ask: "Add the same panes to this project, or start a new pane layout?" If same: copy `role`, `panes`, `theme`, and `colors` from it and skip questions 3 and 5. If new: continue with question 3.
3. Role: ask "What is your role in this project?" with these options. Save the answer as `role` in the repo configuration (`product-owner`, `developer`, or `custom`).
   - Product owner or lead: panes `ceo` (all sections), `todo`, `prs`, `activity`.
   - Developer: panes `ceo` with sections `["reviews","assigned","milestone"]` (call it "My work" when you show it), `prs`, `todo`, `activity`.
   - Custom: ask how many panes (1-6), the type of each (`ceo`, `todo`, `prs`, `activity`), and for CEO which sections (`epics`, `reviews`, `assigned`, `milestone`, `links`; multiSelect).
   Then ask once if the user wants to change any pane.
4. Host: if both Orca and herdr are installed, ask which one this project uses. If only one is installed, use it without asking. Save it as `host` (`"orca"` or `"herdr"`) in the repo configuration.
5. Colors: run questions 2 to 5 in Colors. Save to the shared file.
6. Epics and stories: skip this question if the role is developer and the CEO pane has no `epics` section. Otherwise run `gh issue list --state all --limit 100 --json title,labels`. Infer the epic label and title regex (named group `n`) and the story label and title template (`{n}`). Ask the user to accept or edit. If no epics exist, omit `epics` from the CEO sections.
7. Deadline: list titles from `gh api repos/{owner}/{repo}/milestones` plus "type a date" and "no deadline".
8. Banner on or off (default off).

## Write the configuration

Build JSON with `jq -n`; never hand-write it.

- Repo file `.claude/mobilities.json`: `role`, `host`, `panes`, `epics`, `stories`, `milestone`, `links`, `banner`.
- Shared file `${MOBILITIES_HOME:-~/.config/mobilities}/config.json`: `role`, `panes`, `theme`, `colors`, `font` (the last layout, so the next project can reuse it).

Append `.claude/mobilities.json` and `.claude/mobilities-todo.md` to `.gitignore` if absent. Then run `bin/open.sh`.

## Add a pane

Ask with AskUserQuestion, one question per message:

1. "What do you want in the new pane?" Options (pane, command, install):
   - Git: `lazygit` (`brew install lazygit`).
   - GitHub PRs and issues: `gh dash` (`gh extension install dlvhdr/gh-dash`).
   - Read docs or markdown: `glow` (`brew install glow`). Ask for the file or folder.
   - A web page: `w3m <url>` (`brew install w3m`). Ask for the URL. Say that `carbonyl` (`npm i -g carbonyl`) shows full pages with images if w3m is too plain.
   - System monitor: `btop` (`brew install btop`).
   - Files: `yazi` (`brew install yazi`).
   - Docker: `lazydocker` (`brew install lazydocker`).
   - A mobilities view (`ceo`, `todo`, `prs`, `activity`), or a command the user types.
   The user can select Other. Then ask what they want to see and pick the closest tool or command.
2. If the command is not installed (`command -v`), show its install command and ask before you run it.
3. Ask if this pane gets its own colors (built-in views only). If yes, run the Colors questions and save them as `colors` on this pane.

Append `{ "type": "cmd", "cmd": "<command>", "title": "<short name>" }` (or `{ "type": "<view>" }`) to `panes` in the repo file with `jq`. Then run `bin/open.sh --last`. To remove or move panes, edit `panes` with `jq`, then tell the user to close the old panes and run `/mobilities`.

## Colors

Colors change live: each pane reads them again on its next refresh.

1. Ask "Which panes?": all panes, or one pane (list them by index and type).
2. Ask "Is your terminal light or dark?" Options: dark, light.
3. Ask "Pick a theme": the matching preset (`dark` or `light`), `ocean`, `sunset`, `mono`, `default`, or "Make one from colors I like".
4. If they want their own theme, ask which colors they like (free text is fine: "purple and orange", "#7aa2f7"). Turn the answer into four colors for `heading`, `done`, `warning`, `error` that read well on their background. On a light background, avoid yellow and white. On a dark one, avoid black and blue. A color is a name (black, red, green, yellow, blue, magenta, cyan, white, bright-*) or `#rrggbb`. Show the four colors and ask to accept or edit.
5. Ask "Big headings?" Off, or a figlet font (`small`, `standard`, `slant`). Fonts need `figlet` (`brew install figlet`). The terminal font itself is set in Orca or herdr, not here. Suggest a Nerd Font (https://www.nerdfonts.com) for cleaner symbols.

Save: for all panes, set `theme`, `colors`, and `font` in the shared file. For one pane, set `.panes[i].colors` in the repo file. Use `jq`.

## Pane host not running

If `open.sh` exits 2, show the user its message. Do not start Orca or herdr from inside Claude Code.

## Todo

When the user asks to add or tick todos, edit `.claude/mobilities-todo.md` (`- [ ]` open, `- [x]` done).
