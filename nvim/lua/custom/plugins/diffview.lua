-- Read a whole branch's worth of changes: collapsible file tree on the left,
-- side-by-side diff on the right -- lazygit's Files panel, but in Neovim and
-- with real buffers.
--
-- Single-repo only: diffview resolves one git root from the cwd. A workspace
-- folder holding several repos is not covered by anything here.

vim.pack.add { 'https://github.com/sindrets/diffview.nvim' }

local actions = require 'diffview.actions'

require('diffview').setup {
  keymaps = {
    -- <cr> opens the diff but leaves you in the tree; focus_entry follows the
    -- file, which is what "open this one" should mean. <leader>e comes back.
    file_panel = {
      { 'n', '<cr>', actions.focus_entry, { desc = 'Open the diff and focus it' } },
      { 'n', 'l', actions.focus_entry, { desc = 'Open the diff and focus it' } },
      { 'n', 'o', actions.select_entry, { desc = 'Preview the diff, stay in the tree' } },
    },
  },
  file_panel = {
    listing_style = 'tree',
    tree_options = { folder_statuses = 'only_folded' },
    win_config = { width = 40 },
  },
}

--- diffview finds its repo from the cwd, so point the tab at the repo of the
--- file being read before opening; the tab diffview creates inherits it.
local function in_buffer_repo(cmd)
  return function()
    local status = vim.b.gitsigns_status_dict
    local root = status and status.root
    if not root then
      local dir = vim.fn.expand '%:p:h'
      if dir == '' then dir = assert(vim.uv.cwd()) end
      local dot_git = vim.fs.find('.git', { path = dir, upward = true })[1]
      root = dot_git and vim.fs.dirname(dot_git) or assert(vim.uv.cwd())
    end
    vim.cmd('tcd ' .. vim.fn.fnameescape(root))
    vim.cmd(cmd)
  end
end

-- <leader>gd belongs to repo_diff.lua: it is the multi-repo tree, and diffview
-- only ever sees one repo. What diffview is kept for is the two things the
-- tree does not do -- a whole branch in one panel, and a file's history.
vim.keymap.set('n', '<leader>gD', in_buffer_repo 'DiffviewOpen origin/main...HEAD', { desc = '[G]it: [D]iff whole branch vs main' })
vim.keymap.set('n', '<leader>gh', in_buffer_repo 'DiffviewFileHistory %', { desc = '[G]it: file [h]istory' })
