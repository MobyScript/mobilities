# mobilities

mobilities is a live project dashboard for your terminal. You start it from Claude Code.

![The four mobilities panes in Orca or herdr, next to the pane where you run Claude Code](docs/images/layout.png)

One command opens a set of panes next to your Claude Code session. A pane is one section of the terminal window. Each pane shows one view of your GitHub repo and refreshes on its own.

| Pane | What it shows | Refresh |
|---|---|---|
| Pilot | The project you are on: repo, branch, unpushed and uncommitted work, the PR for this branch with its CI and review state, and counts of reviews, assigned issues, and open PRs | 1 min |
| CEO | Epic progress bars, PRs that wait for your review, issues assigned to you, a milestone checklist with a countdown, and project links | 10 min |
| Todo | Your todo list, from a markdown file that you and Claude both edit. With `fzf`, you can tick, add, and delete items in the pane | 5 s |
| PR watch | Your open PRs, with the CI status and review state of each one. With `fzf`, you can preview a PR and read its diff | 2 min |
| Activity | Recent commits, merged PRs, and new issues in the repo | 5 min |

mobilities also gives you a PR review brief. Claude summarizes the PR, the linked issue, and the comment thread. Then Claude reviews the diff.

## Requirements

You need these tools:

- [Claude Code](https://claude.com/claude-code)
- A pane host: [Orca](https://orca.build) or [herdr](https://herdr.dev). Orca keeps a separate workspace for each project, so each project keeps its own panes. herdr keeps one shared session for all projects.
- [GitHub CLI](https://cli.github.com) (`gh`). Log in with `gh auth login` before you start.
- `jq`

On macOS, install the command line tools with one command:

```sh
brew install gh jq
```

Install Orca from https://orca.build, or install herdr with `brew install herdr`.

## Install

Run these two commands in Claude Code:

```
/plugin marketplace add mobyscript/mobilities
/plugin install mobilities@mobilities
```

## Use

Open Claude Code in a GitHub repo and run this command:

```
/mobilities
```

### First run in a project: onboarding

When you run `/mobilities` in a repo for the first time, Claude first checks your tools, your pane host, your GitHub login, and the issues and milestones of the repo. Then Claude asks its questions in tabs, up to four at a time. It leaves out each question whose answer it already knows.

The first tabs ask about the layout:

1. Earlier setup: If you set up mobilities in a different project before, you can use the same panes and look again.
2. Role: Each role has default panes.
   - Product owner or lead: Pilot, CEO (all sections), Todo, PR watch, and Activity.
   - Developer: Pilot, My work (the CEO pane with only review requests, assigned issues, and the milestone), PR watch, Todo, and Activity.
   - Custom: you select the number of panes, the view in each pane, and the CEO sections.
3. Pane host: If both Orca and herdr are installed, you select one.
4. Layout: Cockpit or right side. See "Layouts" below.

The next tabs ask about the look: light or dark terminal, the color theme, the heading font, and the banner. The last tabs ask about the project: how your repo marks epics and stories, and which milestone the countdown uses.

Claude saves the answers for this repo to `.claude/mobilities.json`. Claude adds that file to `.gitignore`, so your teammates do not see it. Claude saves your role, layout, panes, and look to `~/.config/mobilities/config.json` too, so the next project can use them again. Then Claude opens your panes.

### Layouts

The cockpit layout puts the Pilot pane in a strip across the top. Below it, Todo and Activity are on the left, the Claude Code chat is in the middle, and CEO and PR watch are on the right. Only herdr can make this layout. Orca can only split a pane to the right or down, so in Orca all panes go in a column to the right of the chat. To change the layout later, run `/mobilities layout`.

### Each run after the first

`/mobilities` opens the saved layout immediately. Claude does not ask questions. Each project has its own configuration, so a different project can have a different role and different panes.

### Commands

| Command | What it does |
|---|---|
| `/mobilities` | Starts onboarding on the first run in a repo. After that, opens your panes. |
| `/mobilities setup` | Starts onboarding again, so you can change your layout or colors. |
| `/mobilities add` | Asks what you need, then adds one pane for it. |
| `/mobilities colors` | Changes the colors of all panes or of one pane. |
| `/mobilities layout` | Changes between the cockpit layout and the right side layout. |
| `/mobilities review <PR#>` | Shows a review brief for a PR, then a review of its diff. |

### Add a pane

`/mobilities add` asks what you want to see. Then Claude adds a pane that runs a terminal tool, so you do not need a browser tab for it:

| You want | Tool | Install |
|---|---|---|
| Git history, staging, and branches | `lazygit` | `brew install lazygit` |
| GitHub PRs and issues | `gh dash` | `gh extension install dlvhdr/gh-dash` |
| Docs and markdown files | `glow` | `brew install glow` |
| A web page | `w3m <url>` | `brew install w3m` |
| CPU and memory use | `btop` | `brew install btop` |
| Files | `yazi` | `brew install yazi` |
| Docker containers | `lazydocker` | `brew install lazydocker` |

You can also add one of the mobilities views, or any command that you type. If the tool is not installed, Claude shows the install command and asks before it runs it. The new pane opens next to Claude Code. Your other panes stay open.

To remove or move a pane, ask Claude. Then close the old panes and run `/mobilities` again.

### Colors and fonts

`/mobilities colors` asks if your terminal is light or dark. Then you select a preset theme, or you tell Claude which colors you like, for example "purple and orange". Claude makes a theme from them that you can read on your background. You can change all panes or only one pane. The panes show the new colors on their next refresh. You do not have to reopen them.

A color is a name (`red`, `bright-cyan`) or a hex value (`#7aa2f7`). Hex colors need a terminal that supports 24-bit color.

For big headings, install `figlet` (`brew install figlet`) and select a font. `small` and `slant` draw outline letters. `ANSI Shadow` and `ANSI Regular` draw filled block letters. Claude downloads the filled fonts to `~/.config/mobilities/fonts` when you select one. Orca or herdr sets the terminal font itself. A [Nerd Font](https://www.nerdfonts.com) shows the symbols more clearly.

### Interactive panes

If `fzf` is installed (`brew install fzf`), you can use the Todo and PR watch panes with the keyboard. Click the pane first.

| Pane | Key | What it does |
|---|---|---|
| Todo | Enter | Ticks or unticks the selected item |
| Todo | Type text, then alt-enter | Adds the text as a new item |
| Todo | ctrl-d | Deletes the selected item |
| PR watch | Up and down arrows | Shows the PR and its checks in the preview |
| PR watch | Enter | Shows the full diff of the PR. Press q to go back |
| PR watch | ctrl-r | Loads the list again |

Without `fzf`, the two panes only display.

### Todo list

The Todo pane reads `.claude/mobilities-todo.md`. Git ignores this file too.

```markdown
# This week

- [x] Assign the epic
- [ ] Review PR #80
- [ ] Merge everything and test
```

You can edit the file, or you can tell Claude to mark items as done. The pane shows the change in 5 seconds or less.

## Configuration

You do not have to edit the configuration. Onboarding writes it for you.

This is the default configuration for a repo, in `.claude/mobilities.json`:

```json
{
  "role": "product-owner",
  "host": "orca",
  "panes": [
    { "type": "ceo", "sections": ["epics", "reviews", "assigned", "milestone", "links"] },
    { "type": "todo" },
    { "type": "prs" },
    { "type": "activity" },
    { "type": "cmd", "cmd": "lazygit", "title": "Git" }
  ],
  "epics": { "label": "epic", "title": "Epic(?<n>[0-9]+)" },
  "stories": { "label": "user-story", "title": "^US-{n}-" },
  "milestone": "Final presentation",
  "links": { "wiki": "https://github.com/<owner>/<repo>/wiki" },
  "banner": false
}
```

This is the shared configuration for all your projects, in `~/.config/mobilities/config.json`:

```json
{
  "role": "product-owner",
  "panes": [{ "type": "ceo" }, { "type": "todo" }, { "type": "prs" }, { "type": "activity" }],
  "theme": "default",
  "colors": { "heading": "cyan", "done": "green", "warning": "yellow", "error": "red" },
  "font": "small"
}
```

The themes are `default`, `dark`, `light`, `ocean`, `sunset`, and `mono`. Values in `colors` replace the theme colors. To give one pane its own colors, add `"colors"` to that pane in `.claude/mobilities.json`.

## License

MIT
