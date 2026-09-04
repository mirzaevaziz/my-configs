# my-configs

Reference copies of my personal editor configs and agent skills. These are snapshots synced from my machine — not symlinked, so they may lag the live versions. Take whatever's useful.

## `nvim/`

Neovim configuration — a [`kickstart.nvim`](https://github.com/nvim-lua/kickstart.nvim) fork, standalone only (the old `vscode-neovim` branching on `vim.g.vscode` is gone; VS Code now runs its own keybindings, see below). Plugins come from Neovim's built-in `vim.pack`, not `lazy.nvim`. Snapshot covers `init.lua`, the `lua/custom/plugins/` files, and the one kickstart plugin overridden (`neo-tree.lua`).

**Language servers:** `ts_ls`, `eslint`, `basedpyright`, `ruff`, and `lua_ls`, installed via Mason. C# uses [`roslyn.nvim`](https://github.com/seblyng/roslyn.nvim) rather than the `servers` table — the Roslyn server speaks LSP extensions for solution loading that plain lspconfig cannot handle, and it needs the `roslyn-language-server` dotnet global tool on `$PATH`. OmniSharp is discontinued.

**Formatting** (conform): `stylua` for Lua, `ruff_organize_imports` + `ruff_format` for Python, `prettierd` (falling back to `prettier`) for JS/TS/React, `csharpier` for C#.

**Custom plugins** — these replace the VS Code panels:

- `git.lua` — `<leader>gg` opens lazygit in the repo of the *current file*, not Neovim's cwd, so a workspace holding several repos works unconfigured. Also `<leader>gr`/`gs`/`gc`/`gb`. Gutter and per-hunk actions come from gitsigns.
- `docker.lua` — `<leader>d*` docker compose commands, scoped the same way (nearest `compose.yaml` at or above the current file).
- `flash.lua` — `f`/`F` jump and treesitter-node motions, `r`/`R` operators, `<C-s>` toggle in search. Char mode stays off so `t`/`T` remain stock vim.
- `lists.lua` — `<leader>x` / `<leader>X` toggle the quickfix and location lists, which are separate and do not share commands.
- `scrolling.lua` — `<C-d>`/`<C-u>` and `n`/`N` re-centre the cursor after moving.

**Other changes from stock kickstart:** relative line numbers; telescope `find_files` and `live_grep` show hidden files but exclude `.git/`; blink.cmp uses the `super-tab` preset plus `<CR>` to accept; neo-tree gets vim-style `h`/`l` folder navigation (stock leaves `h` unmapped and binds `l` to `focus_preview`).

**Not snapshotted:** `nvim-pack-lock.json` (gitignored upstream) and the rest of the kickstart tree, which is unmodified.

## `vs_code/keybindings.json`

VS Code keybinding overrides. Vim-flavored, with native VS Code commands (not dependent on `vscode-neovim`).

**Vim-style list and editor navigation:**

- `j` / `k` — move down / up in any list when focus is on a list (not an input)
**Editor navigation and layout — `hjkl` across four modifiers:**

| keys | action |
| --- | --- |
| `cmd+j` / `cmd+k` | previous / next editor |
| `cmd+h` / `cmd+l` | previous / next group (cycles by group order, wraps) |
| `cmd+shift+hjkl` | move the active editor to the group left / below / above / right, splitting one if it doesn't exist |
| `cmd+opt+hjkl` | focus the group left / below / above / right (spatial) |
| `cmd+ctrl+h` / `cmd+ctrl+l` | shrink / grow the focused view — sidebar or editor group |
| `cmd+ctrl+j` / `cmd+ctrl+k` | reorder the active editor tab left / right *within* its group |

**Focus modes:**

| keys | action |
| --- | --- |
| `cmd+opt+f` | maximize the focused editor group — hides sidebar and panel, keeps tabs, no OS fullscreen |
| `cmd+opt+z` | Zen Mode — hides all chrome and goes OS fullscreen (`esc esc` to exit) |

`cmd+opt+f` is scoped `!findWidgetVisible` so the default `toggleFindReplace` keeps the key while the find widget is open. Trade-off: no maximizing until the widget is closed with `esc`. `cmd+opt+z` is additive — the default `cmd+k z` still works. Zen's OS-fullscreen half is a setting, not a binding: `"zenMode.fullScreen": false` in `settings.json` keeps it in-window (settings aren't synced by this repo).

`cmd+j` / `cmd+k` also cycle the suggestion widget, Quick Open results, and terminal panes when those have focus — those `when`-scoped bindings sit *below* in the file, so they win in their own context.

Defaults that had to be displaced: `cmd+shift+k` (`deleteLines`), `cmd+shift+l` (select all occurrences), `cmd+l` (expand line selection — needs an explicit `-expandLineSelection` entry). Extension bindings on `alt+cmd+j/k` (`rest-client`, `claude-code.insertAtMentioned`, `insertSnippet`) are unbound so spatial focus reaches them.

`cmd+h` only reaches VS Code once macOS "Hide" is reassigned. Per machine, not synced by this repo:

```sh
defaults write com.microsoft.VSCode NSUserKeyEquivalents \
  -dict-add "Hide Visual Studio Code" '@~^$h'
```

Then fully quit VS Code (`cmd+Q`) and reopen. Equivalent to System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts. The menu title must match exactly — Insiders needs `Hide Visual Studio Code - Insiders`.

**Terminal:**

- `cmd+enter` — toggle terminal panel
- `shift+cmd+enter` — open a terminal in an editor tab
- `cmd+ctrl+enter` — toggle maximized panel
- `cmd+d` (terminal focused) — new terminal in active workspace
- `cmd+w` (terminal focused) — kill terminal; in a terminal editor tab, close the tab
- `cmd+]` / `cmd+[` — focus next / previous terminal
- `shift+enter` (terminal) — send `Esc`+`Enter` (useful for shells that bind alt+enter)
- `ctrl+escape` — return focus from terminal to the editor
- `cmd+r` (terminal focused) — rename the terminal tab (`workbench.action.terminal.rename`, no default binding)

**Herdr compatibility:**

- `shift+cmd+[` / `shift+cmd+]` — unbound from `previousEditor` / `nextEditor`, freed up for herdr's `previous_tab` / `next_tab`

**Views:**

- `cmd+e` — focus Explorer (overrides default `shift+cmd+e`)
- `cmd+m` — focus Source Control (overrides default `ctrl+shift+g`)

**Other:**

- `shift+cmd+d` — duplicate selection
- `ctrl+shift+p` — trigger parameter hints (overrides command palette default in editor)
- `cmd+; cmd+l` — rerun last test (replaces default debug-last-run binding)
- `ctrl+shift+alt+w` — close panel

## `fish/`

[Fish shell](https://fishshell.com) config. Mirror of `~/.config/fish/` (excludes `fish_variables`, history, and auto-generated completions).

### `config.fish`

Locale, PATH, `zoxide`/`fzf` init, aliases. Commands live in `functions/` (fish autoloads each on first call).

### `functions/`

- **`repos-syncall [dir]`** — fetch + safe-pull every git repo under `dir` (default cwd). Fetches all repos **in parallel** (network is the bottleneck) with a live braille spinner and `N/M` progress counter; SSH runs in `BatchMode` + `ConnectTimeout=10` so an unloaded key or dead connection fails fast instead of hanging. Per repo: skips diverged/ahead, fast-forwards clean-and-behind, and for dirty-and-behind prompts `[y/N/a/q]` to stash → pull → pop (`a` = yes-to-all, `q` = quit); keeps the stash on conflict and lists them at the end.
- **`repos-info [dir]`** — VS Code-style status list for every repo under `dir` (default cwd): branch, dirty count, ahead/behind arrows.
- **`cs`** / **`cs-update-all`** — codebase-search helpers.
- **`repos-tomain`** — switch every repo under cwd to its default branch (stashes dirty ones on confirm). Run inside a repo and it acts on that repo instead of its children.
- **`repos-revert [dir] [--dry-run]`** — VS Code "Discard All Changes" across every repo under `dir` (default cwd). Commits and branches are never touched. Per repo it prompts separately for staged (`git restore --staged --worktree`), working tree (`git restore --worktree` + `git clean -fdx`), and — only once something was actually reverted there — stashes (`git stash clear`). Keys are `[y/N/a/i/q]`: `a` = yes to the rest of *this* repo, `i` = list the affected files then re-ask, `q` = quit the run. **`clean -fdx` also deletes gitignored files** (`bin/`, `obj/`, `.env`, …) with no git-side recovery — `--dry-run` previews exactly what each repo would lose. Paths in `$repos_revert_keep` (default `.codesearch.db`) are excluded; override with `set -g repos_revert_keep a b c`.

### `conf.d/`

- **`rustup.fish`** — rustup/cargo env (machine-generated).

## `karabiner/karabiner.json`

[Karabiner-Elements](https://karabiner-elements.pqrs.org) config. Three complex-modification rules in the default profile:

- **caps_lock → hyper / escape** — held, it's `ctrl+opt+shift`; tapped alone, `escape`.
- **hyper+`hjkl` → arrow keys** — `ctrl+opt+shift+hjkl` sends left / down / up / right, so vim motions work in any app.
- **`cmd+h` disable** — `"enabled": false`. Left in the file as a switch, not active.

That last rule is off on purpose. `cmd+H` is not a system hotkey — it's a **Hide** menu item in each app's own App menu, so a Karabiner rule can only swallow the key globally, which would also block the `cmd+h` binding VS Code needs. Freeing it per app is [`NSUserKeyEquivalents`](#vs_codekeybindingsjson) instead. If you ever do want it dead everywhere *except* VS Code, enable the rule and scope it:

```json
"conditions": [
    {
        "type": "frontmost_application_unless",
        "bundle_identifiers": ["^com\\.microsoft\\.VSCode$"]
    }
]
```

## Raycast (not versioned)

Nothing to commit — Raycast keeps its state in an encrypted `raycast-enc.sqlite` plus a `com.raycast.macos` plist that's mostly machine-local noise (per-monitor window position caches, analytics IDs, migration dates). None of it diffs or transplants.

To move it to a new machine: **Raycast Settings → Advanced → Export Settings & Data**, which writes a binary `.rayconfig`. Import through the same panel. Deliberately kept out of this repo: it's opaque to review, silently rots against reality, and if password-encrypted it's useless without the password anyway.

Worth recording since it's invisible in the export:

- Global hotkey — `cmd+space` (stored as `raycastGlobalHotkey = "Command-49"`).
- Per-command hotkeys live in the encrypted sqlite. When a keybinding elsewhere mysteriously stops firing, check Raycast Settings → Extensions and sort by the hotkey column — window-management commands like to sit on `cmd+ctrl` and `cmd+opt`, which is exactly where [the VS Code `hjkl` layers](#vs_codekeybindingsjson) live.

## `herdr/config.toml`

[Herdr](https://herdr.dev) keybindings (terminal multiplexer for coding agents).

- `prefix+n` / `cmd+]` — next tab
- `prefix+p` / `cmd+[` — previous tab
- `cmd+shift+]` / `cmd+shift+[` — next / previous agent
- `prefix+1..9` / `cmd+shift+1..9` — switch to tab N

**macOS screenshot conflict:** `switch_tab`'s `cmd+shift+1..9` range includes `cmd+shift+3`, `cmd+shift+4`, and `cmd+shift+5` — macOS's default screenshot shortcuts (full screen, selection, Screenshot app). Those intercept the keystroke before herdr sees it, so tabs 3/4/5 won't switch. Fix: System Settings → Keyboard → Keyboard Shortcuts → Screenshots, and disable (or remap) "Save picture of screen as a file", "Save picture of selected area as a file", and "Screenshot and recording options".

## `herdr/`

[Herdr](https://herdr.dev) subagent wiring for Claude Code and pi.dev — how delegated/parallel work gets its own labeled herdr tab instead of an invisible in-process run.

- **`skills/`** — snapshot of `~/.agents/skills/herdr` (the `herdr` skill Claude Code loads via `~/.claude/skills/herdr`, a symlink to that path). `SKILL.md` documents the routing rules; `scripts/claude_pane.py` and `scripts/pi_pane.py` are the one-call drivers that split a tab, start the agent, send the prompt, and harvest the result.
- **`hooks/`** — snapshot of `~/.claude/hooks/herdr-subagent-redirect.sh` (a `PreToolUse` hook on `Task|Agent` that blocks Claude Code's in-process Agent tool under `HERDR_ENV=1` and tells the caller to use `claude_pane.py` instead) and `herdr-agent-state.sh` (`SessionStart` hook that drives herdr's tab-state tracking).
- **`setup.sh`** — installs the above onto a fresh machine: copies the skill + scripts to `~/.agents/skills/herdr`, copies the hooks to `~/.claude/hooks/`, symlinks `~/.claude/skills/herdr -> ../../.agents/skills/herdr`, and `jq`-merges the two hook registrations into `~/.claude/settings.json` (idempotent — skips entries already present, leaves the rest of the file untouched). Requires `jq`.

## `skills/`

Personal agent skills, packaged as `SKILL.md` files with frontmatter (`name`, `description`, etc.) — the format is agent-agnostic and works with any tool that loads SKILL files.

- **[`engineering/cleanup-branches`](skills/engineering/cleanup-branches/SKILL.md)** — Delete unwanted local branches from every git repo under the current working directory. Protects `main` / `master` / `develop` and the currently checked-out branch; confirms the full list before deleting.
- **[`engineering/create-branch`](skills/engineering/create-branch/SKILL.md)** — Create the same logically-named branch across one or more selected repos under the current working directory. Each repo resolves its own naming template via `git config branch.naming.template` (with a sensible default); branches are created locally from a freshly-fetched `origin/main`.
