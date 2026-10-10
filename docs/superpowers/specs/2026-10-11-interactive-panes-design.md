# Interactive panes, heading sizes, profiles, and a configurable config folder

Version 0.4.0. Closes issue #1.

## Goals

1. Every pane is a clickable list. A double-click opens the details in the terminal.
2. The user picks the heading size: off, small, or big. The default no longer wraps or pushes content off the screen.
3. Onboarding shows every style in live panes. The user picks, and the choice is saved as a named profile.
4. The repo configuration can live outside `.claude/` (issue #1).
5. The problems from the feature check on 2026-10-11 are fixed.

## Interactive panes

All five panes (Pilot, CEO, Todo, PR watch, Activity) run on fzf when fzf is installed and `--once` is not given. Without fzf, or with `--once`, the panes print plain text as they do now.

A new function `pick` in `bin/lib.sh` holds the fzf setup that `todo.sh` and `prs.sh` repeat today:

1. The live reload: `--listen 0`, the port file, and the background `curl` loop that posts `reload(...)`.
2. The theme colors, read again on each reload, so a theme change reaches the pane without a restart.
3. The mouse (fzf default), with `double-click` bound to the same action as Enter.
4. The keys, given by the caller.

Each pane prints rows as `kind<TAB>id<TAB>text`. fzf shows only the text (`--with-nth 3..`). The kinds are:

| kind | id | Enter or double-click opens |
|---|---|---|
| `pr` | PR number | `gh pr view N --comments` and `gh pr checks N` in `less -R` |
| `issue` | issue number | `gh issue view N --comments` in `less -R` |
| `commit` | sha | `git show --color=always <sha>` in `less -R` |
| `link` | URL | `w3m <url>` if installed, else `open <url>` |
| `todo` | line number | toggles the item (Todo pane only) |
| empty | empty | nothing (headings and plain lines) |

The details open in the same pane. The user presses q to go back to the list. One function `open_row kind id` in `lib.sh` holds this table, so all panes act the same.

Pilot, CEO, and Activity have no search box (`--no-input`). In these panes, f cycles the heading size and r reloads. Todo and PR watch keep their search box, so they use alt-f and ctrl-r.

PR watch keeps Enter for the diff. Its preview window hides below 80 columns (`--preview-window 'right,50%,<80(hidden)'`). An empty list shows one "(none)" row.

Todo fixes: alt-enter clears the query after it adds an item (`+clear-query`). Rows show ✓ and ☐ in place of `- [x]` and `- [ ]`. Rows appear in file order (`--layout=reverse`).

## Heading sizes

The shared `config.json` gets two keys:

1. `heading`: `off`, `small`, or `big`. The default is `off`.
2. `fonts`: `{ "small": "<figlet font>", "big": "<figlet font>" }`. The defaults are the Pagga font for small (3 rows) and ANSI Shadow for big (6 rows), downloaded into `~/.config/mobilities/fonts/`.

The old `font` key still works. If `heading` is missing and `font` is set, the pane uses `font` as the big font and the size is `big`.

The `header` function in `lib.sh` changes as follows:

1. Only the first heading of each render uses the figlet font. Later headings use the one-line form.
2. The figlet font is used only when standard output is a terminal. The review brief and the banner always get one line.
3. If the figlet output is wider than the pane (`tput cols`), the heading falls back to one line.

The f key (alt-f in Todo and PR watch) writes the next size to `heading` in the shared file and reloads the pane at once. The other panes pick it up on their next reload. `/mobilities font off|small|big` does the same from Claude.

The ocean preset uses `bright-blue` for headings so they stay readable on a dark terminal.

## Style preview and profiles

A new script `bin/preview.sh` opens one live pane for each choice, in the configured host (a new herdr tab, or panes on the right in Orca):

1. `preview.sh fonts` opens the Pilot pane three times, with `MOBILITIES_HEADING` set to `off`, `small`, and `big`.
2. `preview.sh themes` opens the Pilot pane once for each preset, with `MOBILITIES_THEME` set to the preset.

`lib.sh` reads `MOBILITIES_HEADING` and `MOBILITIES_THEME` before the shared file, so the preview panes show real data in each style. Each preview pane shows its option name on the first line.

Onboarding runs `preview.sh themes`, asks the theme question, closes the preview, then does the same for fonts. Then it asks for a profile name (default `default`).

A profile holds `role`, `layout`, `panes`, `theme`, `colors`, `heading`, and `fonts`. It is stored as `profiles.<name>` in the shared `config.json`. The top-level keys of the shared file stay the active look, so the panes read them as before. When the user picks a profile:

1. The skill copies the profile into the top-level keys of the shared file.
2. The skill copies `role`, `layout`, and `panes` into the repo file.

`/mobilities profile <name>` applies a saved profile. `/mobilities profile save <name>` saves the current look and layout. In onboarding, if profiles exist, the first question lists them next to "Start a new one".

## Configurable config folder (issue #1)

A new function `repo_dir` in `lib.sh` returns the folder for `mobilities.json` and `mobilities-todo.md`:

1. If `MOBILITIES_DIR` is set, it returns that folder. A relative path is relative to the repo root.
2. If `.mobilities/mobilities.json` exists, it returns `.mobilities`.
3. Otherwise it returns `.claude`.

`CFG` in `lib.sh`, `F` in `todo.sh`, and `banner.sh` use `repo_dir`. `banner.sh` stops using its own fixed path.

When onboarding writes a new configuration, it writes to `MOBILITIES_DIR` if set, to the folder of an existing file if one exists, and otherwise to `.claude/`. It adds the two file paths in that folder to `.gitignore`. The README documents `MOBILITIES_DIR`, `MOBILITIES_HOME`, and the lookup order.

## Other fixes

1. `open.sh` sends the output of `herdr pane swap` to `/dev/null`.
2. On a detached HEAD, Pilot shows the short commit id in place of the branch name.

## Testing

`tests/run.sh` gets checks for:

1. `pick` and `open_row`: each kind runs the right command (with the fake `gh`).
2. The heading: off, small, and big; the fallback when the pane is narrow; one line when output is not a terminal; the big font only on the first heading; the old `font` key.
3. The f key writes the next size to the shared file.
4. Profiles: save, then apply, then compare the shared and repo files.
5. `repo_dir`: `MOBILITIES_DIR`, `.mobilities/`, and `.claude/`. `banner.sh` follows `MOBILITIES_DIR`.
6. Todo: ✓ and ☐ rows, file order, and the query clears after an add.
7. Pilot on a detached HEAD.
8. `open.sh` prints no JSON from swaps.

All existing checks must pass.

## Process

1. Codex writes the code on branch `feat/interactive-panes` in the worktree `../mobilities-interactive`. The uncommitted changes in the main working copy stay untouched.
2. Claude reviews the diff and runs `bash tests/run.sh`.
3. Claude opens the new panes from the worktree in a herdr tab against the real repo, and runs both previews. The user tries them.
4. Nothing goes to GitHub until the user approves.
5. Claude raises `.claude-plugin/plugin.json` to 0.4.0 and opens one PR that says "Closes #1".

## Amendment (2026-10-11): agent pane and one live preview

This section replaces "Style preview and profiles" where they differ.

1. The shared `config.json` and profiles get an `agent` key: the command for the chat pane (`claude`, `codex`, `opencode`, or any command). If it is missing, mobilities uses `claude` when `CLAUDECODE=1`, else `claude`.
2. `bin/preview.sh` takes no arguments. It opens one new tab, starts the agent in the first pane, then runs `open.sh` anchored at that pane, so the tab matches the user's real layout. In Orca it renames the tab to "mobilities preview" after the panes start. It prints `Close with: <command>`.
3. The t key cycles the theme (default, dark, light, ocean, sunset, mono) in Pilot, CEO, and Activity. Todo and PR watch use alt-t. Any pane script accepts `--cycle-theme`. The value is saved as `theme` in the shared file.
4. Onboarding asks for the agent in tab group 1. The look step opens the preview, asks the user to press f and t until they like the look, then asks "Keep this look?" or "Make one from colors I like", then closes the preview.
5. `MOBILITIES_HEADING` and `MOBILITIES_THEME` stay as overrides, but `preview.sh` no longer uses them.
