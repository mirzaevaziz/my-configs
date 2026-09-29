# my-configs

Reference copies of my personal editor configs and agent skills. These are snapshots synced from my machine — not symlinked, so they may lag the live versions. Take whatever's useful.

## `Brewfile` / `MANUAL_APPS.md`

The full inventory of what's installed on this Mac.

`Brewfile` is a `brew bundle dump` — taps, formulae and casks. Restore on a new machine with `brew bundle install`. VS Code extensions are deliberately excluded (`--no-vscode`): Settings Sync already carries them, and a second list just drifts.

`MANUAL_APPS.md` covers the rest: apps in `/Applications` that Homebrew doesn't own, split into ones with a cask available (adopt with `brew install --cask --adopt <token>`), ones with no cask, MDM-managed work apps, and macOS built-ins.

Refresh both with `./dump-packages.sh` — it rewrites `Brewfile` and prints the current manual list to reconcile against the notes in `MANUAL_APPS.md` by hand.

## `nvim/`

Neovim configuration — a [`kickstart.nvim`](https://github.com/nvim-lua/kickstart.nvim) fork, standalone only (the old `vscode-neovim` branching on `vim.g.vscode` is gone; VS Code now runs its own keybindings, see below). Plugins come from Neovim's built-in `vim.pack`, not `lazy.nvim`. Snapshot covers `init.lua`, the `lua/custom/plugins/` files, and the one kickstart plugin overridden (`neo-tree.lua`).

**Language servers:** `ts_ls`, `eslint`, `basedpyright`, `ruff`, and `lua_ls`, installed via Mason. C# uses [`roslyn.nvim`](https://github.com/seblyng/roslyn.nvim) rather than the `servers` table — the Roslyn server speaks LSP extensions for solution loading that plain lspconfig cannot handle, and it needs the `roslyn-language-server` dotnet global tool on `$PATH`. OmniSharp is discontinued.

**Formatting** (conform): `stylua` for Lua, `ruff_organize_imports` + `ruff_format` for Python, `prettierd` (falling back to `prettier`) for JS/TS/React, `csharpier` for C#.

**Custom plugins** — these replace the VS Code panels:

- `git.lua` — `<leader>gg` opens lazygit in the repo of the *current file*, not Neovim's cwd, so a workspace holding several repos works unconfigured. Also `<leader>gr`/`gs`/`gc`/`gb`. Gutter and per-hunk actions come from gitsigns.
- `repo_diff.lua` — the Source Control panel across *several* repos, which no git TUI does. `:RepoDiff [dir]`, `<leader>gd` (or the `repos-review` fish function) lists every dirty repo under the cwd at depth 1 — the cwd itself if it is a repo, otherwise its direct children — as a lazygit-style file tree: single-child directories squash into one row (`f` toggles), green = fully staged, red = work tree still differs. Keymaps follow diffview.nvim's file panel: `<CR>`/`l` open the working copy against `HEAD` in a native side-by-side diff and hide the tree, `o` previews without leaving it, `<Tab>`/`<S-Tab>` step files, `h`/`za`/`zR`/`zM` fold, `-`/`s` stage or unstage, `S`/`U` stage/unstage the whole repo, `X` discards a file (asks first), `R` rescans, `g?` help. `<leader>e` refocuses the tree on the row you left, `<leader>gt`/`<leader>b` toggle it. Committing stays in lazygit (`<leader>gg`), hunk actions in gitsigns.
- `diffview.lua` — [diffview.nvim](https://github.com/sindrets/diffview.nvim) for the two things the multi-repo tree does not do: `<leader>gD` diffs the whole branch against `origin/main`, `<leader>gh` shows the current file's history. Single-repo only, so both first `tcd` to the repo of the current buffer. File-panel keys match `repo_diff.lua` (`<CR>`/`l` focus the diff, `o` previews).
- `docker.lua` — `<leader>d*` docker compose commands, scoped the same way (nearest `compose.yaml` at or above the current file).
- `flash.lua` — `f`/`F` jump and treesitter-node motions, `r`/`R` operators, `<C-s>` toggle in search. Char mode stays off so `t`/`T` remain stock vim.
- `lists.lua` — `<leader>x` / `<leader>X` toggle the quickfix and location lists, which are separate and do not share commands.
- `scrolling.lua` — `<C-d>`/`<C-u>` and `n`/`N` re-centre the cursor after moving.
- `markdown.lua` — markdown reading. Buffers open as plain source; `<leader>mv` toggles the rendered view (render-markdown.nvim plus snacks.nvim inline images — Ghostty speaks the kitty graphics protocol, so images draw in the buffer), and `<leader>mp` opens markdown-preview.nvim in a browser for what the terminal cannot draw, i.e. mermaid and math. markdown-preview runs from its bundled node app, built once with `cd .../markdown-preview.nvim/app && yarn install`; the upstream prebuilt binary is unsigned and macOS refuses to exec it (`E903: Unknown system error -88`), so do not let `mkdp#util#install()` restore an `app/bin/` — it takes priority over the node path.

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

**Freed keys:**

- `shift+cmd+[` / `shift+cmd+]` — unbound from `previousEditor` / `nextEditor`, originally freed for herdr's `previous_tab` / `next_tab` (herdr is gone; the keys stay unbound)

**Views:**

- `cmd+e` — focus Explorer (overrides default `shift+cmd+e`)
- `cmd+m` — focus Source Control (overrides default `ctrl+shift+g`)

**Other:**

- `shift+cmd+d` — duplicate selection
- `ctrl+shift+p` — trigger parameter hints (overrides command palette default in editor)
- `cmd+; cmd+l` — rerun last test (replaces default debug-last-run binding)
- `ctrl+shift+alt+w` — close panel

## `ghostty/config`

[Ghostty](https://ghostty.org) terminal config. Mirror of `~/.config/ghostty/config`. Theme and font match Neovim's `tokyonight-night` and JetBrainsMono Nerd Font.

**`hjkl` across four modifiers — mirrors [the VS Code layers](#vs_codekeybindingsjson):**

| keys | action |
| --- | --- |
| `cmd+h` / `cmd+l` | previous / next tab |
| `cmd+j` / `cmd+k` | scroll the scrollback down / up |
| `cmd+shift+hjkl` | new split left / down / up / right |
| `cmd+opt+hjkl` | focus the split left / below / above / right (spatial) |
| `cmd+ctrl+h` / `cmd+ctrl+l` | shrink / grow the focused split by 10 |
| `cmd+ctrl+j` / `cmd+ctrl+k` | move the active tab left / right |

Tabs moved to `h`/`l` so `j`/`k` could take scrollback, matching vim's vertical motion. Split *cycling* was dropped in the trade — `cmd+opt+hjkl` already focuses splits spatially, which is strictly better. Scrollback is bound as `text:` sending PgDn/PgUp rather than Ghostty's `scroll_page_down`/`scroll_page_up`: alt-screen TUIs (Claude Code, nvim) scroll themselves and ignore the terminal's own scrollback actions. Plain shell scrollback still answers to `shift+fn+up` / `shift+fn+down`.

The VS Code analogue of `cmd+shift+hjkl` *moves* the editor into the group in that direction. Ghostty 1.3.1 has no move-surface-between-splits action, so these create a split instead — the closest available behavior.

Ghostty defaults left in place: `cmd+t` new tab, `cmd+n` new window, `cmd+1`–`cmd+8` goto tab, `cmd+9` last tab, `cmd+opt+w` close tab, `cmd+d` split right, `cmd+shift+enter` split zoom, `cmd+ctrl+=` equalize. Two defaults are explicitly `unbind`-ed: `cmd+shift+d` (split down) since `cmd+shift+j` owns that direction, and `cmd+shift+w` (close window) to free the key for a macOS App Shortcut on "Move Tab to New Window". Defaults and overrides merge — `ghostty +list-keybinds` prints the resolved set.

Note `cmd+shift+[` / `cmd+shift+]` still switch tabs here as a Ghostty default, while [`vs_code/keybindings.json`](#vs_codekeybindingsjson) unbinds them.

`cmd+h` only reaches Ghostty once macOS "Hide" is reassigned. Per machine, not synced by this repo:

```sh
defaults write com.mitchellh.ghostty NSUserKeyEquivalents \
  -dict-add "Hide Ghostty" '@~^$h'
```

Reload a running instance with `cmd+shift+,`. Validate edits with `ghostty +validate-config`.

**Telling tabs apart.** Ghostty 1.3.1 has no per-tab color: on macOS the tab bar inherits the surface background, so the only way to tint one tab is `OSC 11`, which repaints that tab's whole background. Colored backgrounds per project were tried and dropped — they fight the `tokyonight-night` theme the editor is matched to. What ships instead is a colored dot in the tab title, driven from the shell: [`fish/functions/fish_title.fish`](#functions) and [`ssh.fish`](#functions).

## `fish/`

[Fish shell](https://fishshell.com) config. Mirror of `~/.config/fish/` (excludes `fish_variables`, history, and auto-generated completions).

The `club2` ssh alias in the live `config.fish` is host-specific and deliberately not mirrored. Secrets live in the gitignored [`conf.d/secrets.fish`](#confd), never in `config.fish`.

### `config.fish`

Locale, PATH, `zoxide`/`fzf` init, aliases. Commands live in `functions/` (fish autoloads each on first call).

### `functions/`

- **`repos-syncall [dir]`** — fetch + safe-pull every git repo under `dir` (default cwd). Fetches all repos **in parallel** (network is the bottleneck) with a live braille spinner and `N/M` progress counter; SSH runs in `BatchMode` + `ConnectTimeout=10` so an unloaded key or dead connection fails fast instead of hanging. Per repo: skips diverged/ahead, fast-forwards clean-and-behind, and for dirty-and-behind prompts `[y/N/a/q]` to stash → pull → pop (`a` = yes-to-all, `q` = quit); keeps the stash on conflict and lists them at the end.
- **`repos-info [dir]`** — VS Code-style status list for every repo under `dir` (default cwd): branch, dirty count, ahead/behind arrows.
- **`repos-diff [dir] [--full|-f]`** — review unmerged work across every repo under `dir` (default cwd), straight to the terminal. Per repo it diffs from the merge-base with `origin/HEAD`, so you see everything the branch added, committed or not — the same range a reviewer sees on the PR page — falling back to `HEAD` (uncommitted only) where there is no default branch. Clean repos and `_tmp` scratch dirs are skipped. Default output is a `--stat` summary; `--full` prints the whole diff.
- **`repos-review [dir]`** — opens the Neovim panel above (`repo_diff.lua`) on `dir` (default cwd) in its own instance, so the scope is the shell's cwd rather than an editing session's. Pairs with **`repos-diff`**, which dumps the same changes to the terminal instead.
- **`cs`** / **`cs-update-all`** — codebase-search helpers.
- **`fish_title`** — the Ghostty tab label: a colored dot plus the shortened cwd. The dot is the point — `~/Projects/adnoc` is blue, `epam` green, `self` purple, `skills` yellow, `~/learn-terminal` orange, anything else white, and a shell with `SSH_TTY` set is red. Fish re-runs `fish_title` every prompt, so the dot follows `cd` with nothing to trigger by hand. See [why it is a dot and not a colored tab](#ghosttyconfig).
- **`ssh`** — wraps `ssh` to set the tab title to a red dot plus the host argument before handing off, so a tab sitting on a remote host is obvious at a glance. Titles set by the remote shell take over from there; the next local prompt restores `fish_title`.
- **`repos-tomain`** — switch every repo under cwd to its default branch (stashes dirty ones on confirm). Run inside a repo and it acts on that repo instead of its children.
- **`repos-revert [dir] [--dry-run]`** — VS Code "Discard All Changes" across every repo under `dir` (default cwd). Commits and branches are never touched. Per repo it prompts separately for staged (`git restore --staged --worktree`), working tree (`git restore --worktree` + `git clean -fdx`), and — only once something was actually reverted there — stashes (`git stash clear`). Keys are `[y/N/a/i/q]`: `a` = yes to the rest of *this* repo, `i` = list the affected files then re-ask, `q` = quit the run. **`clean -fdx` also deletes gitignored files** (`bin/`, `obj/`, `.env`, …) with no git-side recovery — `--dry-run` previews exactly what each repo would lose. Paths in `$repos_revert_keep` (default `.codesearch.db`) are excluded; override with `set -g repos_revert_keep a b c`.

### `conf.d/`

- **`rustup.fish`** — rustup/cargo env (machine-generated).
- **`secrets.fish`** — gitignored, not in this repo. Holds `ADNOC_FEED_TOKEN` (an Azure DevOps PAT) and `AZURE_DEVOPS_EXT_PAT`. Lives in `conf.d/` so fish autoloads it before `config.fish`; `chmod 600`. On a new machine, create it by hand — nothing here will.

## `karabiner/karabiner.json`

[Karabiner-Elements](https://karabiner-elements.pqrs.org) config. Three complex-modification rules in the default profile:

- **caps_lock → hyper / escape** — held, it's `ctrl+opt+shift`; tapped alone, `escape`.
- **hyper+`hjkl` → arrow keys** — `ctrl+opt+shift+hjkl` sends left / down / up / right, so vim motions work in any app.
- **home row mods** — `f`/`d`/`s` held are left `cmd`/`opt`/`ctrl`, `j`/`k`/`l` the right-hand ones; tapped, the letter. Held means 150 ms (`basic.to_if_held_down_threshold_milliseconds`); another key inside that window cancels the hold and types the letter (`to_delayed_action.to_if_canceled`), so fast rolls stay letters. Listed after the hyper rule so `hyper+jkl` still reaches the arrows — Karabiner takes the first match.

Trade-offs, accepted: the letter lands on key-up, holding a home-row key never auto-repeats it (scroll with `hyper+j`/`k`), and only one home-row modifier at a time — `f+d` does not stack into `cmd+opt`. Karabiner has no real hold-tap engine (no permissive-hold or roll detection); if misfires pile up, [kanata](https://github.com/jtroo/kanata)'s `tap-hold-release` with `tap-hold-require-prior-idle` is the upgrade path, but it replaces Karabiner-Elements entirely rather than running beside it.

A third rule disabling `cmd+h` was deleted rather than kept as a switch. `cmd+H` is not a system hotkey — it's a **Hide** menu item in each app's own App menu, so a Karabiner rule can only swallow the key globally, which would also block the `cmd+h` binding VS Code needs. Freeing it per app is [`NSUserKeyEquivalents`](#vs_codekeybindingsjson) instead. If you ever do want it dead everywhere *except* VS Code, enable the rule and scope it:

```json
"conditions": [
    {
        "type": "frontmost_application_unless",
        "bundle_identifiers": ["^com\\.microsoft\\.VSCode$", "^com\\.mitchellh\\.ghostty$"]
    }
]
```

## Raycast (not versioned)

Nothing to commit — Raycast keeps its state in an encrypted `raycast-enc.sqlite` plus a `com.raycast.macos` plist that's mostly machine-local noise (per-monitor window position caches, analytics IDs, migration dates). None of it diffs or transplants.

To move it to a new machine: **Raycast Settings → Advanced → Export Settings & Data**, which writes a binary `.rayconfig`. Import through the same panel. Deliberately kept out of this repo: it's opaque to review, silently rots against reality, and if password-encrypted it's useless without the password anyway.

Worth recording since it's invisible in the export:

- Global hotkey — `cmd+space` (stored as `raycastGlobalHotkey = "Command-49"`).
- Per-command hotkeys live in the encrypted sqlite. When a keybinding elsewhere mysteriously stops firing, check Raycast Settings → Extensions and sort by the hotkey column — window-management commands like to sit on `cmd+ctrl` and `cmd+opt`, which is exactly where [the VS Code `hjkl` layers](#vs_codekeybindingsjson) live.

## `skills/`

Personal agent skills, packaged as `SKILL.md` files with frontmatter (`name`, `description`, etc.) — the format is agent-agnostic and works with any tool that loads SKILL files.

- **[`engineering/cleanup-branches`](skills/engineering/cleanup-branches/SKILL.md)** — Delete unwanted local branches from every git repo under the current working directory. Protects `main` / `master` / `develop` and the currently checked-out branch; confirms the full list before deleting.
- **[`engineering/create-branch`](skills/engineering/create-branch/SKILL.md)** — Create the same logically-named branch across one or more selected repos under the current working directory. Each repo resolves its own naming template via `git config branch.naming.template` (with a sensible default); branches are created locally from a freshly-fetched `origin/main`.
