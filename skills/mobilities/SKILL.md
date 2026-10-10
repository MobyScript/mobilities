---
name: mobilities
description: Open live GitHub project panes (Pilot overview, CEO, Todo, PR watch, Activity) and terminal tool panes (lazygit, gh dash, glow, w3m) in Orca or herdr next to Claude Code. Runs onboarding the first time in a repo. Use for /mobilities, /mobilities setup, /mobilities add, /mobilities colors, /mobilities layout, /mobilities review <PR#>, or when the user asks to open, add, recolor, or change their project dashboard panes.
---

# mobilities

Scripts live at `<this skill's base directory>/../../bin/`. Call them by absolute path.

## Arguments

- Empty: if `.claude/mobilities.json` exists in the repo root, run `bin/open.sh` and report what opened. Otherwise run Onboarding.
- `setup`: run Onboarding.
- `add`: run Add a pane.
- `colors`: run Colors.
- `layout`: ask the Layout question from Onboarding, save `layout` and each pane's `side`, then tell the user to close the panes and run `/mobilities`.
- `review <N>`: run `bin/review.sh <N>` and show the output. Then run `gh pr diff <N>` and review the diff for correctness and security against the linked issue's acceptance criteria. Report findings, most severe first.

## Onboarding

### Step 1: gather everything first

Before you ask anything, run all the checks in one Bash call:

- `gh auth status`, `gh repo view --json nameWithOwner`, `command -v jq orca herdr fzf figlet`.
- Which host runs this session: `ORCA_TERMINAL_HANDLE` set means Orca, `HERDR_ENV=1` means herdr.
- The tools that a pane can use: `command -v lazygit gh-dash glow w3m btop yazi lazydocker` and `gh extension list`.
- `gh issue list --state all --limit 100 --json title,labels` (to infer epics and stories) and `gh api repos/{owner}/{repo}/milestones`.
- `${MOBILITIES_HOME:-~/.config/mobilities}/config.json`, if it exists (an earlier setup).

If `gh` or `jq` is missing, or `gh` is not logged in, stop and tell the user. If neither Orca nor herdr is installed, recommend Orca (https://orca.build) and offer herdr (https://herdr.dev, `brew install herdr`). Use what you found to drop questions whose answer is already known, and to put the most likely answer first, marked "(Recommended)".

### Step 2: ask in tabs

Ask with AskUserQuestion. Put up to 4 questions in one call, so they show as tabs. Do not send one question per message.

Tab group 1:

1. Earlier setup (only if the shared file exists): show its `role` and pane types. "Add the same panes to this project, or start a new pane layout?" If same, copy `role`, `panes`, `theme`, `colors`, `font`, and `layout` from it and drop questions 2, 4, and tab group 2.
2. Role. Save as `role` (`product-owner`, `developer`, or `custom`).
   - Product owner or lead: panes `pilot`, `ceo` (all sections), `todo`, `prs`, `activity`.
   - Developer: panes `pilot`, `ceo` with sections `["reviews","assigned","milestone"]` (call it "My work"), `prs`, `todo`, `activity`.
   - Custom: after this call, ask how many panes (1-7), the type of each (`pilot`, `ceo`, `todo`, `prs`, `activity`, or a tool from "Add a pane"), and for CEO which sections (`epics`, `reviews`, `assigned`, `milestone`, `links`; multiSelect).
3. Host (only if both Orca and herdr are installed). Recommend the one that runs this session. Save as `host`.
4. Layout. Save as `layout`.
   - Cockpit (herdr only): the pilot pane is a strip on top, then panes on the left, the chat in the middle, and panes on the right. Put `todo` and `activity` on the left (`"side": "left"`), `ceo` and `prs` on the right, and `pilot` on top (`"side": "top"`).
   - Right side: all panes in a column to the right of the chat. This is the only layout Orca can make, because Orca cannot split left or up.

Tab group 2 (the look):

1. "Is your terminal light or dark?"
2. Theme: the matching preset (`dark` or `light`), `ocean`, `sunset`, `mono`, `default`, or "Make one from colors I like". If they want their own, ask for the colors after this call (see Colors, question 4).
3. Headings: off, an outline font (`slant`, `small`, `standard`), or a filled font (`ANSI Shadow`, `ANSI Regular`). The user picks. Show each option as a preview of the word TODO.
4. Banner on or off (default off).

Tab group 3 (the project, only the questions that apply):

1. Epics and stories: skip if the CEO pane has no `epics` section. Show the epic label and title regex (named group `n`) and the story label and title template (`{n}`) that you inferred, and ask to accept or edit. If no epics exist, drop the `epics` section and this question.
2. Deadline: the milestone titles, plus "type a date" and "no deadline". Skip if there are no milestones and offer only "type a date" or "no deadline".

Fonts: figlet needs `brew install figlet`. A filled font is not part of figlet. Download it once, then save its path as `font`:

```sh
mkdir -p ~/.config/mobilities/fonts
curl -fsSL -o ~/.config/mobilities/fonts/ansi-shadow.flf "https://raw.githubusercontent.com/xero/figlet-fonts/master/ANSI%20Shadow.flf"
curl -fsSL -o ~/.config/mobilities/fonts/ansi-regular.flf "https://raw.githubusercontent.com/xero/figlet-fonts/master/ANSI%20Regular.flf"
```

Ask before you install or download anything.

## Write the configuration

Build JSON with `jq -n`; never hand-write it.

- Repo file `.claude/mobilities.json`: `role`, `host`, `layout`, `panes`, `epics`, `stories`, `milestone`, `links`, `banner`.
- Shared file `${MOBILITIES_HOME:-~/.config/mobilities}/config.json`: `role`, `layout`, `panes`, `theme`, `colors`, `font` (the last layout, so the next project can reuse it).

Append `.claude/mobilities.json` and `.claude/mobilities-todo.md` to `.gitignore` if absent. Then run `bin/open.sh`.

## Add a pane

Run `command -v` for every tool below first. Then ask with AskUserQuestion. Ask question 1 alone, then questions 2 and 3 together in one call:

1. "What do you want in the new pane?" Options (pane, command, install):
   - Git: `lazygit` (`brew install lazygit`).
   - GitHub PRs and issues: `gh dash` (`gh extension install dlvhdr/gh-dash`).
   - Read docs or markdown: `glow` (`brew install glow`). Ask for the file or folder.
   - A web page: `w3m <url>` (`brew install w3m`). Ask for the URL. Say that `carbonyl` (`npm i -g carbonyl`) shows full pages with images if w3m is too plain.
   - System monitor: `btop` (`brew install btop`).
   - Files: `yazi` (`brew install yazi`).
   - Docker: `lazydocker` (`brew install lazydocker`).
   - A mobilities view (`pilot`, `ceo`, `todo`, `prs`, `activity`), or a command the user types.
   In the cockpit layout, also ask which side: left or right.
   The user can select Other. Then ask what they want to see and pick the closest tool or command.
2. If the command is not installed (`command -v`), show its install command and ask before you run it.
3. Ask if this pane gets its own colors (built-in views only). If yes, run the Colors questions and save them as `colors` on this pane.

Append `{ "type": "cmd", "cmd": "<command>", "title": "<short name>" }` (or `{ "type": "<view>" }`) to `panes` in the repo file with `jq`. Then run `bin/open.sh --last`. To remove or move panes, edit `panes` with `jq`, then tell the user to close the old panes and run `/mobilities`.

## Colors

Colors change live: each pane reads them again on its next refresh. Ask questions 1, 2, 3, and 5 in one AskUserQuestion call (tabs). Ask question 4 after it, only if needed.

1. Ask "Which panes?": all panes, or one pane (list them by index and type).
2. Ask "Is your terminal light or dark?" Options: dark, light.
3. Ask "Pick a theme": the matching preset (`dark` or `light`), `ocean`, `sunset`, `mono`, `default`, or "Make one from colors I like".
4. If they want their own theme, ask which colors they like (free text is fine: "purple and orange", "#7aa2f7"). Turn the answer into four colors for `heading`, `done`, `warning`, `error` that read well on their background. On a light background, avoid yellow and white. On a dark one, avoid black and blue. A color is a name (black, red, green, yellow, blue, magenta, cyan, white, bright-*) or `#rrggbb`. Show the four colors and ask to accept or edit.
5. Ask "Big headings?" Off, an outline font (`small`, `standard`, `slant`), or a filled font (`ANSI Shadow`, `ANSI Regular`, downloaded as in Onboarding). The user picks. Fonts need `figlet` (`brew install figlet`). The terminal font itself is set in Orca or herdr, not here. Suggest a Nerd Font (https://www.nerdfonts.com) for cleaner symbols.

Save: for all panes, set `theme`, `colors`, and `font` in the shared file. For one pane, set `.panes[i].colors` in the repo file. Use `jq`.

## Interactive panes

If `fzf` is installed, the Todo and PR watch panes are interactive. In Todo, Enter ticks or unticks an item, alt-enter adds the typed text as a new item, and ctrl-d deletes an item. In PR watch, the preview shows the PR and its checks, and Enter shows the full diff. Without `fzf`, both panes only display. If the user asks for interactive panes and `fzf` is missing, offer `brew install fzf`.

## Pane host not running

If `open.sh` exits 2, show the user its message. Do not start Orca or herdr from inside Claude Code.

## Todo

When the user asks to add or tick todos, edit `.claude/mobilities-todo.md` (`- [ ]` open, `- [x]` done).
