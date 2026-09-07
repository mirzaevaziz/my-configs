-- Multi-repo Source Control panel: repo tree on the left, side-by-side diff on
-- the right.
--
-- git.lua already covers the single-repo case (lazygit + telescope, scoped to
-- the current buffer's repo). What is missing is the overview across a
-- *workspace* folder whose children are repos -- the thing VS Code gives you
-- for free and no git TUI does at all.
--
-- Scope is the cwd, depth 1: if the cwd is itself a repo that is the whole
-- list, otherwise every direct child holding a .git. Read-only by design --
-- staging and committing stay in lazygit, which is better at them.

local M = {}

local ns = vim.api.nvim_create_namespace 'repo_diff'
local PANEL_WIDTH = 44

--- @return string|nil stdout, or nil when git exits non-zero
local function git(repo, args)
  local cmd = { 'git', '-C', repo }
  vim.list_extend(cmd, args)
  local done = vim.system(cmd, { text = true }):wait()
  return done.code == 0 and done.stdout or nil
end

--- The cwd itself if it is a repo, else its direct children that are.
local function find_repos(root)
  if vim.uv.fs_stat(root .. '/.git') then return { root } end

  local found = {}
  for name, type in vim.fs.dir(root) do
    -- a linked worktree has .git as a *file*, so stat rather than isdirectory
    if type == 'directory' and vim.uv.fs_stat(root .. '/' .. name .. '/.git') then
      table.insert(found, root .. '/' .. name)
    end
  end
  table.sort(found)
  return found
end

--- Modified-tracked + untracked, NUL separated so paths with spaces or quotes
--- come through verbatim.
local function changes(repo)
  local out = git(repo, { 'status', '--porcelain', '-z', '--untracked-files=all' })
  if not out then return {} end

  local fields = vim.split(out, '\0', { trimempty = true })
  local files, i = {}, 1
  while i <= #fields do
    local xy, path = fields[i]:sub(1, 2), fields[i]:sub(4)
    -- a rename/copy is followed by a second field holding the *old* path
    if xy:sub(1, 1) == 'R' or xy:sub(1, 1) == 'C' then i = i + 1 end
    table.insert(files, { xy = xy, path = path })
    i = i + 1
  end
  return files
end

local state = { root = nil, buf = nil, win = nil, entries = {}, line = 1 }

local function render()
  local lines, entries, marks = {}, {}, {}

  for _, repo in ipairs(find_repos(state.root)) do
    local files = changes(repo)
    if #files > 0 then
      local branch = vim.trim(git(repo, { 'branch', '--show-current' }) or '')
      table.insert(lines, ('%s  %s'):format(vim.fs.basename(repo), branch ~= '' and branch or 'detached'))
      table.insert(marks, { line = #lines - 1, col = 0, len = #vim.fs.basename(repo), hl = 'Directory' })

      for _, f in ipairs(files) do
        table.insert(lines, ('  %s %s'):format(f.xy, f.path))
        entries[#lines] = { repo = repo, path = f.path }
        table.insert(marks, { line = #lines - 1, col = 2, len = 2, hl = 'DiagnosticWarn' })
      end
    end
  end

  if #lines == 0 then lines = { 'no changes under ' .. vim.fs.basename(state.root) } end

  state.entries = entries
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(state.buf, ns, m.line, m.col, { end_col = m.col + m.len, hl_group = m.hl })
  end
end

--- Working tree on the left (real, editable, saves), HEAD on the right.
local function open_diff()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local entry = state.entries[row]
  if not entry then return end
  state.line = row

  -- One diff pair at a time. Without this every <CR> stacks another vsplit
  -- next to the last one. Scratch buffers are bufhidden=wipe so they go with
  -- their window; a real file you edited stays loaded and modified, hidden.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= state.win then pcall(vim.api.nvim_win_close, win, false) end
  end
  vim.api.nvim_set_current_win(state.win)
  vim.api.nvim_win_set_width(state.win, PANEL_WIDTH)
  vim.cmd 'rightbelow vsplit'

  vim.cmd('edit ' .. vim.fn.fnameescape(entry.repo .. '/' .. entry.path))
  local work_win = vim.api.nvim_get_current_win()
  local filetype = vim.bo.filetype

  -- An untracked file has no HEAD version, so the scratch stays empty and the
  -- whole file reads as added -- same as VS Code.
  local head = git(entry.repo, { 'show', 'HEAD:' .. entry.path })
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split((head or ''):gsub('\n$', ''), '\n'))
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = filetype
  vim.bo[buf].modifiable = false
  -- URI-ish name so Neovim does not resolve it against the cwd
  pcall(vim.api.nvim_buf_set_name, buf, 'repodiff://HEAD/' .. entry.path)

  vim.cmd 'rightbelow vsplit'
  vim.api.nvim_win_set_buf(0, buf)
  vim.cmd 'diffthis'
  vim.api.nvim_set_current_win(work_win)
  vim.cmd 'diffthis'

  -- the tree has done its job; give the diff the full width
  M.toggle()
  vim.api.nvim_set_current_win(work_win)
end

local function open_panel()
  vim.cmd 'topleft vsplit'
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.api.nvim_win_set_width(state.win, PANEL_WIDTH)

  vim.bo[state.buf].buftype = 'nofile'
  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].filetype = 'repodiff'
  vim.wo[state.win].winfixwidth = true
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = 'no'
  vim.wo[state.win].cursorline = true

  vim.keymap.set('n', '<CR>', open_diff, { buffer = state.buf, desc = 'Diff this file against HEAD' })
  vim.keymap.set('n', 'R', render, { buffer = state.buf, desc = 'Rescan repos' })
  vim.keymap.set('n', 'q', M.toggle, { buffer = state.buf, desc = 'Hide the panel' })

  render()
  local last = vim.api.nvim_buf_line_count(state.buf)
  vim.api.nvim_win_set_cursor(state.win, { math.min(state.line or 1, last), 0 })
end

--- Hide the tree to read a diff full width, bring it back to pick the next
--- file. The scan is not redone on hide, so the cursor lands where you left it.
function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    state.line = vim.api.nvim_win_get_cursor(state.win)[1]
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  else
    if not state.root then state.root = assert(vim.uv.cwd()) end
    open_panel()
  end
end

function M.open(root)
  state.root = (vim.fs.normalize(vim.fn.fnamemodify(root or assert(vim.uv.cwd()), ':p')):gsub('/$', ''))
  state.line = 1
  open_panel()
end

vim.keymap.set('n', '<leader>gt', M.toggle, { desc = '[G]it: toggle repo [t]ree' })

vim.api.nvim_create_user_command('RepoDiff', function(opts)
  M.open(opts.args ~= '' and opts.args or nil)
end, { nargs = '?', complete = 'dir', desc = 'Source Control panel across every repo under a folder' })

return M
