-- Git: the Source Control panel, replaced.
--
-- gitsigns (configured in init.lua) already handles the gutter and per-hunk
-- actions, and it attaches per buffer -- so in a workspace holding several
-- repos, every file talks to its own repo with no extra setup.
--
-- What is missing is the "overview" half of the VS Code panel. lazygit covers
-- that, but it is a cwd-scoped program: launched from a folder that merely
-- *contains* repos it fails with "not a git repository". So we always launch it
-- in the repo of the file you are looking at, not in Neovim's cwd.

--- Repo root for the current buffer, falling back to an upward .git search
--- (gitsigns has not attached yet) and finally to the cwd.
--- @return string
local function buffer_repo_root()
  local status = vim.b.gitsigns_status_dict
  if status and status.root then return status.root end

  local dir = vim.fn.expand '%:p:h'
  if dir == '' then dir = assert(vim.uv.cwd()) end
  local dot_git = vim.fs.find('.git', { path = dir, upward = true })[1]
  return dot_git and vim.fs.dirname(dot_git) or assert(vim.uv.cwd())
end

local function open_lazygit()
  if vim.fn.executable 'lazygit' == 0 then
    vim.notify('lazygit is not installed: brew install lazygit', vim.log.levels.ERROR)
    return
  end

  local root = buffer_repo_root()
  vim.cmd 'tabnew'
  vim.fn.jobstart({ 'lazygit' }, {
    term = true,
    cwd = root,
    on_exit = function()
      -- Close the terminal tab, then let gitsigns notice anything lazygit did.
      if vim.api.nvim_buf_is_valid(0) then vim.cmd 'bdelete!' end
      require('gitsigns').refresh()
    end,
  })
  vim.cmd 'startinsert'
end

vim.keymap.set('n', '<leader>gg', open_lazygit, { desc = '[G]it: lazy[g]it (this file\'s repo)' })

vim.keymap.set('n', '<leader>gr', function()
  vim.notify('repo: ' .. buffer_repo_root(), vim.log.levels.INFO)
end, { desc = '[G]it: which [r]epo is this file in?' })

-- Changed files, scoped to the current buffer's repo -- the closest thing to
-- the VS Code Source Control file list.
vim.keymap.set('n', '<leader>gs', function()
  require('telescope.builtin').git_status { cwd = buffer_repo_root() }
end, { desc = '[G]it: changed files ([s]tatus)' })

vim.keymap.set('n', '<leader>gc', function()
  require('telescope.builtin').git_commits { cwd = buffer_repo_root() }
end, { desc = '[G]it: [c]ommit log' })

vim.keymap.set('n', '<leader>gb', function()
  require('telescope.builtin').git_branches { cwd = buffer_repo_root() }
end, { desc = '[G]it: [b]ranches' })
