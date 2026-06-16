# my-configs

Reference copies of my personal editor configs and agent skills. These are snapshots synced from my machine — not symlinked, so they may lag the live versions. Take whatever's useful.

## `nvim/init.lua`

Neovim configuration. Runs both as standalone Neovim and inside the [`vscode-neovim`](https://github.com/vscode-neovim/vscode-neovim) extension; behavior branches on `vim.g.vscode`.

**Plugin manager:** [`lazy.nvim`](https://github.com/folke/lazy.nvim) — auto-bootstraps on first launch (clones itself into `stdpath("data")/lazy/`).

**Plugins:**

- [`flash.nvim`](https://github.com/folke/flash.nvim) — `f`/`F` jump motions (char mode disabled to preserve native `f`/`F`/`t`/`T`), treesitter node selection, remote/treesitter-search operators
- [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) — syntax highlighting, indent, incremental selection (`<C-space>`), and textobjects (`af`/`if`/`ac`/`ic` for around/inside function/class)
- [`nvim-ts-context-commentstring`](https://github.com/JoosepAlviste/nvim-ts-context-commentstring) — context-aware comment strings

**Treesitter parsers installed:** `bash`, `c`, `cpp`, `css`, `c_sharp`, `html`, `javascript`, `json`, `lua`, `markdown`, `markdown_inline`, `python`, `query`, `rust`, `tsx`, `typescript`, `vim`, `yaml`.

**Notable mappings** (`<leader>` = space):

- `<leader>c` — open `~/.config/nvim/init.lua`
- `<leader>s` — write buffer
- `<leader><Esc>` — clear search highlighting
- `U` — redo (i.e. `<C-r>`)
- `p` in visual mode — paste without overwriting the register
- `j` / `k` — move by visual line (skip wrapped-line folds)

**Global options:** system clipboard sync (`unnamedplus`), `ignorecase` + `smartcase`, `termguicolors`.

### VS Code mode (`vim.g.vscode` is set)

Adds leader mappings that delegate to VS Code commands via `VSCodeNotify`:

- `<leader>b` / `<leader>t` — focus / toggle primary sidebar
- `<leader>e` / `<leader>f` / `<leader>g` / `<leader>x` — focus Explorer / Search / Source Control / Extensions
- `<leader>q` — open Problems panel
- `<leader>ca` — Quick Fix
- `<leader>h` / `<leader>l` / `<leader>k` / `<leader>j` — focus editor group left / right / above / below
- `]d` / `[d` — next / previous diagnostic in files
- `]e` / `[e` — next / previous diagnostic in current file
- `gd` / `gD` — Go to Implementation / Peek Implementations

### Pure Neovim mode (otherwise)

- `<C-d>` / `<C-u>` — half-page scroll with auto-center

## `vs_code/keybindings.json`

VS Code keybinding overrides. Vim-flavored, with native VS Code commands (not dependent on `vscode-neovim`).

**Vim-style list and editor navigation:**

- `j` / `k` — move down / up in any list when focus is on a list (not an input)
- `cmd+k` / `cmd+j` — next / previous editor (also: cycles suggestion widget, Quick Open results, and terminal panes when those have focus)

**Editor group movement:**

- `cmd+shift+k` / `cmd+shift+j` — move active editor to next / previous group (overrides default `deleteLines`)
- `cmd+ctrl+j` / `cmd+ctrl+k` — move active editor left / right

**Terminal:**

- `cmd+enter` — toggle terminal panel
- `shift+cmd+enter` — open a terminal in an editor tab
- `cmd+ctrl+enter` — toggle maximized panel
- `cmd+d` (terminal focused) — new terminal in active workspace
- `cmd+w` (terminal focused) — kill terminal; in a terminal editor tab, close the tab
- `cmd+]` / `cmd+[` — focus next / previous terminal
- `shift+enter` (terminal) — send `Esc`+`Enter` (useful for shells that bind alt+enter)
- `ctrl+escape` — return focus from terminal to the editor

**Views:**

- `cmd+e` — focus Explorer (overrides default `shift+cmd+e`)
- `cmd+m` — focus Source Control (overrides default `ctrl+shift+g`)

**Other:**

- `shift+cmd+d` — duplicate selection
- `ctrl+shift+p` — trigger parameter hints (overrides command palette default in editor)
- `cmd+; cmd+l` — rerun last test (replaces default debug-last-run binding)
- `ctrl+shift+alt+w` — close panel

## `skills/`

Personal agent skills, packaged as `SKILL.md` files with frontmatter (`name`, `description`, etc.) — the format is agent-agnostic and works with any tool that loads SKILL files.

- **[`engineering/cleanup-branches`](skills/engineering/cleanup-branches/SKILL.md)** — Delete unwanted local branches from every git repo under the current working directory. Protects `main` / `master` / `develop` and the currently checked-out branch; confirms the full list before deleting.
