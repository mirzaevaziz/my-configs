-- Multi-repo Source Control panel: lazygit's file tree on the left,
-- side-by-side diff on the right.
--
-- git.lua already covers the single-repo case (lazygit + telescope, scoped to
-- the current buffer's repo). What is missing is the overview across a
-- *workspace* folder whose children are repos -- the thing VS Code gives you
-- for free and no git TUI does at all.
--
-- Scope is the cwd, depth 1: if the cwd is itself a repo that is the whole
-- list, otherwise every direct child holding a .git. Keymaps follow
-- diffview.nvim's file panel, so the two panels are muscle-memory compatible.

local M = {}

local ns = vim.api.nvim_create_namespace 'repo_diff'

-- Reading a diff wants the whole window, so opening a file hides the tree
-- outright rather than shrinking it. <leader>e brings it back, on the row you
-- left. Shown, it takes this share of the screen.
local PANEL_SHARE = 0.3
local MIN_WIDTH = 24

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

local function resize_panel(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  vim.api.nvim_win_set_width(win, math.max(MIN_WIDTH, math.floor(vim.o.columns * PANEL_SHARE)))
end

--- lazygit's colours: green once a change is fully staged, red while the work
--- tree still differs from the index (untracked '??' included).
local function status_hl(xy)
  return xy:sub(2, 2) == ' ' and 'DiagnosticOk' or 'DiagnosticError'
end

-- `collapsed` is keyed by "repo:dir/path" and survives a rescan, so folding a
-- directory shut stays shut while you work through the rest of the list.
local state = {
  root = nil,
  buf = nil,
  win = nil,
  work_win = nil,
  entries = {},
  files = {},
  dir_keys = {},
  line = 1,
  collapsed = {},
  flatten = true,
  listing = 'tree',
}

--- Split every path into a nested {dirs, files} tree, the way lazygit draws it.
local function build_tree(files)
  local root = { dirs = {}, files = {} }
  for _, f in ipairs(files) do
    local parts = vim.split(f.path, '/')
    local node = root
    for i = 1, #parts - 1 do
      node.dirs[parts[i]] = node.dirs[parts[i]] or { dirs = {}, files = {} }
      node = node.dirs[parts[i]]
    end
    table.insert(node.files, { name = parts[#parts], entry = f })
  end
  return root
end

--- A directory holding nothing but one directory is drawn as "a/b/c", one row
--- rather than three -- lazygit's trick, and the reason its tree stays short.
--- Toggled off with `f`, same as diffview's flatten option.
local function squash(name, node)
  while state.flatten and #node.files == 0 and vim.tbl_count(node.dirs) == 1 do
    local child_name, child = next(node.dirs)
    name, node = name .. '/' .. child_name, child
  end
  return name, node
end

local function sorted_dirs(node)
  local names = vim.tbl_keys(node.dirs)
  table.sort(names)
  return names
end

local function add_file_row(out, indent, xy, label, repo, path)
  table.insert(out.lines, ('%s%s %s'):format(indent, xy, label))
  out.entries[#out.lines] = { kind = 'file', repo = repo, path = path, xy = xy }
  local hl = status_hl(xy)
  table.insert(out.marks, { line = #out.lines - 1, col = #indent, len = #xy + #label + 1, hl = hl })
end

--- Depth-first render. `out` collects lines/entries/marks so the caller can
--- push them into the buffer in one go. Directories and their sibling files
--- share an indent column, which is what makes the hierarchy readable.
local function render_node(node, repo, path, depth, out)
  local indent = string.rep('  ', depth)

  for _, dir_name in ipairs(sorted_dirs(node)) do
    local label, child = squash(dir_name, node.dirs[dir_name])
    local dir_path = path == '' and label or (path .. '/' .. label)
    local key = repo .. ':' .. dir_path
    local shut = state.collapsed[key]
    table.insert(state.dir_keys, key)

    table.insert(out.lines, ('%s%s %s'):format(indent, shut and '▶' or '▼', label))
    out.entries[#out.lines] = { kind = 'dir', repo = repo, key = key, path = dir_path }
    table.insert(out.marks, { line = #out.lines - 1, col = #indent, len = #label + 4, hl = 'Directory' })

    if not shut then render_node(child, repo, dir_path, depth + 1, out) end
  end

  table.sort(node.files, function(a, b) return a.name < b.name end)
  for _, f in ipairs(node.files) do
    add_file_row(out, indent, f.entry.xy, f.name, repo, f.entry.path)
  end
end

local function render()
  local out = { lines = {}, entries = {}, marks = {} }
  state.dir_keys, state.files = {}, {}

  for _, repo in ipairs(find_repos(state.root)) do
    local files = changes(repo)
    state.files[repo] = files
    if #files > 0 then
      local branch = vim.trim(git(repo, { 'branch', '--show-current' }) or '')
      table.insert(out.lines, ('%s  %s'):format(vim.fs.basename(repo), branch ~= '' and branch or 'detached'))
      table.insert(out.marks, { line = #out.lines - 1, col = 0, len = #vim.fs.basename(repo), hl = 'Title' })

      if state.listing == 'list' then
        for _, f in ipairs(files) do
          add_file_row(out, '  ', f.xy, f.path, repo, f.path)
        end
      else
        -- The repo's own root is a row, so the whole repo folds with one `h`.
        local key = repo .. ':/'
        table.insert(state.dir_keys, key)
        local shut = state.collapsed[key]
        table.insert(out.lines, ('%s /'):format(shut and '▶' or '▼'))
        out.entries[#out.lines] = { kind = 'dir', repo = repo, key = key, path = '' }
        table.insert(out.marks, { line = #out.lines - 1, col = 0, len = 3, hl = 'Directory' })
        if not shut then render_node(build_tree(files), repo, '', 1, out) end
      end
    end
  end

  if #out.lines == 0 then out.lines = { 'no changes under ' .. vim.fs.basename(state.root) } end

  state.entries = out.entries
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, out.lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, m in ipairs(out.marks) do
    vim.api.nvim_buf_set_extmark(state.buf, ns, m.line, m.col, { end_col = m.col + m.len, hl_group = m.hl })
  end
end

--- Redraw without losing your place: the cursor is restored by line, which is
--- close enough when only a status character changed.
local function rerender()
  local row = state.win and vim.api.nvim_win_get_cursor(state.win)[1] or 1
  render()
  local last = vim.api.nvim_buf_line_count(state.buf)
  if state.win then vim.api.nvim_win_set_cursor(state.win, { math.min(row, last), 0 }) end
end

local function entry_at_cursor()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then return nil end
  return state.entries[vim.api.nvim_win_get_cursor(state.win)[1]]
end

--- Every changed file under a directory row (or the one file, for a file row).
local function entry_files(entry)
  if entry.kind == 'file' then return { entry } end
  local prefix = entry.path == '' and '' or (entry.path .. '/')
  return vim.tbl_filter(function(f) return f.path:sub(1, #prefix) == prefix end, state.files[entry.repo] or {})
end

--- Working tree on the left (real, editable, saves), HEAD on the right.
--- `focus` decides whether you land in the diff or keep reading the tree. The
--- tree is never closed here -- that is what <leader>b is for.
local function open_diff(focus)
  local entry = entry_at_cursor()
  if not entry then return end

  if entry.kind == 'dir' then
    state.collapsed[entry.key] = not state.collapsed[entry.key]
    rerender()
    return
  end
  state.line = vim.api.nvim_win_get_cursor(state.win)[1]

  -- One diff pair at a time. Without this every <CR> stacks another vsplit
  -- next to the last one. Scratch buffers are bufhidden=wipe so they go with
  -- their window; a real file you edited stays loaded and modified, hidden.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= state.win then pcall(vim.api.nvim_win_close, win, false) end
  end
  vim.api.nvim_set_current_win(state.win)
  vim.cmd 'rightbelow vsplit'

  vim.cmd('edit ' .. vim.fn.fnameescape(entry.repo .. '/' .. entry.path))
  local work_win = vim.api.nvim_get_current_win()
  local filetype = vim.bo.filetype
  M.attach_diff_keys(vim.api.nvim_get_current_buf())

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
  M.attach_diff_keys(buf)

  vim.cmd 'rightbelow vsplit'
  vim.api.nvim_win_set_buf(0, buf)
  vim.cmd 'diffthis'
  vim.api.nvim_set_current_win(work_win)
  vim.cmd 'diffthis'

  state.work_win = work_win
  vim.api.nvim_set_current_win(focus and work_win or state.win)

  if focus then
    -- Reading the file: the tree has done its job, give the diff everything.
    -- M.toggle remembers the row, so <leader>e comes back to this file.
    M.toggle()
    vim.api.nvim_set_current_win(work_win)
  else
    -- Still picking: the two vsplits each halved the panel, so restore it last.
    resize_panel(state.win)
  end
end

--- Move to the next/previous file row, skipping directory headers, and open it
--- without leaving the tree -- <tab> reads the whole changeset one file at a
--- time. `from` lets [F and ]F reuse the same walk.
local function step_entry(delta, from)
  local last = vim.api.nvim_buf_line_count(state.buf)
  local start = from or (vim.api.nvim_win_get_cursor(state.win)[1] + delta)
  for candidate = start, delta > 0 and last or 1, delta do
    local entry = state.entries[candidate]
    if entry and entry.kind == 'file' then
      vim.api.nvim_win_set_cursor(state.win, { candidate, 0 })
      open_diff(false)
      return
    end
  end
end

--- Scroll the diff from the tree, lazygit style: the pair is scrollbound by
--- diffthis, so driving one window moves both.
local function scroll_diff(keys)
  if not (state.work_win and vim.api.nvim_win_is_valid(state.work_win)) then return end
  vim.api.nvim_win_call(state.work_win, function() vim.cmd('normal! ' .. keys) end)
end

local function set_fold(shut)
  local entry = entry_at_cursor()
  if not entry then return end
  local key = entry.key
  if entry.kind == 'file' then
    -- fall back to the nearest directory row above, so `h` on a file folds its
    -- parent the way it does in a file explorer
    for row = vim.api.nvim_win_get_cursor(state.win)[1] - 1, 1, -1 do
      if state.entries[row] and state.entries[row].kind == 'dir' then
        key = state.entries[row].key
        vim.api.nvim_win_set_cursor(state.win, { row, 0 })
        break
      end
    end
  end
  if not key then return end
  state.collapsed[key] = shut == nil and not state.collapsed[key] or shut or nil
  rerender()
end

local function set_all_folds(shut)
  for _, key in ipairs(state.dir_keys) do
    state.collapsed[key] = shut or nil
  end
  rerender()
end

--- `-`/`s`: stage when anything under the cursor is still unstaged, unstage
--- once it is all in the index. A directory row acts on its whole subtree.
local function toggle_stage()
  local entry = entry_at_cursor()
  if not entry then return end
  local files = entry_files(entry)
  if #files == 0 then return end

  local all_staged = true
  for _, f in ipairs(files) do
    if f.xy:sub(2, 2) ~= ' ' then all_staged = false end
  end

  local pathspec = entry.kind == 'file' and entry.path or (entry.path == '' and '.' or entry.path)
  if all_staged then
    git(entry.repo, { 'restore', '--staged', '--', pathspec })
  else
    git(entry.repo, { 'add', '--', pathspec })
  end
  rerender()
end

local function stage_all(unstage)
  local entry = entry_at_cursor()
  if not entry then return end
  git(entry.repo, unstage and { 'restore', '--staged', '--', '.' } or { 'add', '--', '.' })
  rerender()
end

--- `X`: throw the file's changes away. Destructive and unrecoverable for
--- untracked files, so it always asks first.
local function restore_entry()
  local entry = entry_at_cursor()
  if not entry or entry.kind ~= 'file' then return end

  local untracked = entry.xy == '??'
  local prompt = untracked and ('Delete untracked %s?'):format(entry.path) or ('Discard all changes in %s?'):format(entry.path)
  if vim.fn.confirm(prompt, '&No\n&Yes', 1) ~= 2 then return end

  if untracked then
    vim.fn.delete(entry.repo .. '/' .. entry.path)
  else
    git(entry.repo, { 'restore', '--staged', '--worktree', '--source=HEAD', '--', entry.path })
  end
  rerender()
end

--- gf / <C-w><C-f> / <C-w>gf: leave the diff behind and just edit the file.
local function goto_file(cmd)
  local entry = entry_at_cursor()
  if not entry or entry.kind ~= 'file' then return end
  local target = vim.fn.fnameescape(entry.repo .. '/' .. entry.path)
  if cmd == 'edit' then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if win ~= state.win then pcall(vim.api.nvim_win_close, win, false) end
    end
    vim.cmd 'rightbelow vsplit'
  end
  vim.cmd((cmd == 'edit' and 'edit ' or cmd .. ' ') .. target)
  vim.cmd 'diffoff'
end

--- Built from the buffer's own keymaps, so it cannot drift from what is bound.
local function help()
  local rows = {}
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(state.buf, 'n')) do
    if map.desc then table.insert(rows, ('  %-12s %s'):format(map.lhs, map.desc)) end
  end
  table.sort(rows)
  table.insert(rows, 1, ' repo_diff keymaps')
  table.insert(rows, 2, '')

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, rows)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  local width = 0
  for _, row in ipairs(rows) do width = math.max(width, #row + 2) end
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = math.min(#rows, vim.o.lines - 6),
    row = 2,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    border = 'rounded',
    style = 'minimal',
  })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  vim.keymap.set('n', '<Esc>', function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
end

--- <leader>e and <leader>b work from inside the diff too, same as diffview.
function M.attach_diff_keys(buf)
  vim.keymap.set('n', '<leader>e', M.focus_tree, { buffer = buf, desc = 'Bring focus to the file panel' })
  vim.keymap.set('n', '<leader>b', M.toggle, { buffer = buf, desc = 'Toggle the file panel' })
end

local function open_panel()
  vim.cmd 'topleft vsplit'
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, state.buf)
  resize_panel(state.win)

  vim.bo[state.buf].buftype = 'nofile'
  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].filetype = 'repodiff'
  vim.wo[state.win].winfixwidth = true
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = 'no'
  vim.wo[state.win].cursorline = true

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = state.buf, desc = desc }) end

  map('<CR>', function() open_diff(true) end, 'Open the diff and focus it')
  map('l', function() open_diff(true) end, 'Open the diff and focus it')
  map('o', function() open_diff(false) end, 'Open the diff, stay in the tree')
  map('<2-LeftMouse>', function() open_diff(true) end, 'Open the diff and focus it')

  map('<Tab>', function() step_entry(1) end, 'Open the diff for the next file')
  map('<S-Tab>', function() step_entry(-1) end, 'Open the diff for the previous file')
  map('[F', function() step_entry(1, 1) end, 'Open the diff for the first file')
  map(']F', function() step_entry(-1, vim.api.nvim_buf_line_count(state.buf)) end, 'Open the diff for the last file')

  map('-', toggle_stage, 'Stage / unstage the entry')
  map('s', toggle_stage, 'Stage / unstage the entry')
  map('S', function() stage_all(false) end, 'Stage every change in this repo')
  map('U', function() stage_all(true) end, 'Unstage every change in this repo')
  map('X', restore_entry, 'Discard the file\'s changes (asks first)')

  map('zo', function() set_fold(false) end, 'Expand fold')
  map('h', function() set_fold(true) end, 'Collapse fold')
  map('zc', function() set_fold(true) end, 'Collapse fold')
  map('za', function() set_fold(nil) end, 'Toggle fold')
  map('zR', function() set_all_folds(false) end, 'Expand all folds')
  map('zM', function() set_all_folds(true) end, 'Collapse all folds')

  map('<C-f>', function() scroll_diff '\004' end, 'Scroll the diff down')
  map('<C-b>', function() scroll_diff '\021' end, 'Scroll the diff up')

  map('gf', function() goto_file 'edit' end, 'Open the file, no diff')
  map('<C-w><C-f>', function() goto_file 'split' end, 'Open the file in a new split')
  map('<C-w>gf', function() goto_file 'tabedit' end, 'Open the file in a new tabpage')

  map('i', function()
    state.listing = state.listing == 'tree' and 'list' or 'tree'
    rerender()
  end, "Toggle between 'list' and 'tree' views")
  map('f', function()
    state.flatten = not state.flatten
    rerender()
  end, 'Flatten empty subdirectories in tree listing style')

  map('R', rerender, 'Update stats and entries in the file list')
  map('<leader>e', function() vim.api.nvim_set_current_win(state.win) end, 'Bring focus to the file panel')
  map('<leader>b', M.toggle, 'Toggle the file panel')
  map('q', M.toggle, 'Hide the panel')
  map('g?', help, 'Open the help panel')

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

--- From inside a diff, jump back to the tree without hunting for the window.
function M.focus_tree()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  else
    M.toggle()
  end
end

function M.open(root)
  state.root = (vim.fs.normalize(vim.fn.fnamemodify(root or assert(vim.uv.cwd()), ':p')):gsub('/$', ''))
  state.line = 1
  open_panel()
end

vim.keymap.set('n', '<leader>gd', M.focus_tree, { desc = '[G]it: [d]iff tree across every repo' })
vim.keymap.set('n', '<leader>gt', M.toggle, { desc = '[G]it: toggle repo [t]ree' })

vim.api.nvim_create_user_command('RepoDiff', function(opts)
  M.open(opts.args ~= '' and opts.args or nil)
end, { nargs = '?', complete = 'dir', desc = 'Source Control panel across every repo under a folder' })

return M
