# mobilities

mobilities is a live project dashboard for your terminal. You start it from Claude Code.

![The four mobilities panes in Orca or herdr, next to the pane where you run Claude Code](docs/images/layout.png)

One command opens a set of panes next to your Claude Code session. A pane is one section of the terminal window. Each pane shows one view of your GitHub repo and refreshes on its own.

| Pane | What it shows | Refresh |
|---|---|---|
| CEO | Epic progress bars, PRs that wait for your review, issues assigned to you, a milestone checklist with a countdown, and project links | 10 min |
| Todo | Your todo list, from a markdown file that you and Claude both edit | 5 s |
| PR watch | Your open PRs, with the CI status and review state of each one | 2 min |
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

When you run `/mobilities` in a repo for the first time, Claude asks you questions. Claude asks one question at a time:

1. Tools: Claude makes sure that `gh` and `jq` work. If you have neither Orca nor herdr, Claude recommends Orca and offers herdr as the alternative.
2. Earlier setup: If you set up mobilities in a different project before, Claude shows the panes from that project. You can add the same panes and colors to this project, or you can start a new pane layout. If you add the same panes, Claude does not ask about your role or colors.
3. Role: You select your role in the project. Each role has default panes:
   - Product owner or lead: CEO (all sections), Todo, PR watch, and Activity.
   - Developer: My work (the CEO pane with only review requests, assigned issues, and the milestone), PR watch, Todo, and Activity.
   - Custom: you select the number of panes, the view in each pane, and the sections that each pane shows. Then Claude asks once if you want to change any pane.
4. Pane host: If both Orca and herdr are installed, you select the one that this project uses. If only one is installed, Claude uses it.
5. Colors: You select a color theme for the panes. You can select a preset theme or give your own colors for headings, done items, and warnings.
6. Epics and stories: Claude reads your existing issues and suggests how your repo marks epics and user stories. Usually you only accept the suggestion. Claude skips this step for a developer who does not keep the epics section.
7. Deadline: You select the GitHub milestone that the countdown uses. You can type a date instead.
8. Banner: You select if the CEO summary prints at the start of each Claude Code session in this repo. The banner is off by default.

Claude saves the answers for this repo to `.claude/mobilities.json`. Claude adds that file to `.gitignore`, so your teammates do not see it. Claude saves your role, panes, and colors to `~/.config/mobilities/config.json` too, so the next project can use them again. Then Claude opens your panes.

### Each run after the first

`/mobilities` opens the saved layout immediately. Claude does not ask questions. Each project has its own configuration, so a different project can have a different role and different panes.

### Commands

| Command | What it does |
|---|---|
| `/mobilities` | Starts onboarding on the first run in a repo. After that, opens your panes. |
| `/mobilities setup` | Starts onboarding again, so you can change your layout or colors. |
| `/mobilities review <PR#>` | Shows a review brief for a PR, then a review of its diff. |

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
    { "type": "activity" }
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
  "colors": { "heading": "cyan", "done": "green", "warning": "yellow", "error": "red" }
}
```

## License

MIT
