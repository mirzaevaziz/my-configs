-- Containers: the Dev Containers panel, replaced.
--
-- Same rule as git (see git.lua): commands are scoped to the project of the file
-- you are looking at, never to Neovim's cwd. That matters here because
-- docker compose resolves its project from the working directory, and a folder
-- that merely *contains* services (e.g. ~/Projects/adnoc/talent) has no compose
-- file of its own.

local COMPOSE_FILES = { 'compose.yaml', 'compose.yml', 'docker-compose.yml', 'docker-compose.yaml' }

--- Nearest directory at or above the current file holding a compose file.
--- @return string|nil dir, string|nil file
local function compose_project()
  local dir = vim.fn.expand '%:p:h'
  if dir == '' then dir = assert(vim.uv.cwd()) end
  local found = vim.fs.find(COMPOSE_FILES, { path = dir, upward = true, type = 'file' })[1]
  if not found then return nil, nil end
  return vim.fs.dirname(found), found
end

--- Run a command in a terminal tab, rooted at the compose project.
--- @param cmd string[]
local function in_project_terminal(cmd)
  local dir = compose_project()
  if not dir then
    vim.notify('No compose file found above ' .. vim.fn.expand '%:p:h', vim.log.levels.WARN)
    return
  end
  vim.cmd 'tabnew'
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = dir,
    on_exit = function()
      -- Leave the tab open: compose output is the point. Close it with :q.
      vim.notify(table.concat(cmd, ' ') .. '  (' .. vim.fn.fnamemodify(dir, ':t') .. ')')
    end,
  })
  vim.cmd 'startinsert'
end

vim.keymap.set('n', '<leader>dd', function()
  if vim.fn.executable 'lazydocker' == 0 then
    vim.notify('lazydocker is not installed: brew install lazydocker', vim.log.levels.ERROR)
    return
  end
  -- lazydocker is daemon-wide, not project-scoped, so cwd does not matter.
  vim.cmd 'tabnew'
  vim.fn.jobstart({ 'lazydocker' }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(0) then vim.cmd 'bdelete!' end
    end,
  })
  vim.cmd 'startinsert'
end, { desc = '[D]ocker: lazy[d]ocker' })

vim.keymap.set('n', '<leader>du', function()
  in_project_terminal { 'docker', 'compose', 'up', '-d' }
end, { desc = '[D]ocker: compose [u]p -d' })

vim.keymap.set('n', '<leader>dw', function()
  in_project_terminal { 'docker', 'compose', 'down' }
end, { desc = '[D]ocker: compose do[w]n' })

vim.keymap.set('n', '<leader>dl', function()
  in_project_terminal { 'docker', 'compose', 'logs', '-f', '--tail', '100' }
end, { desc = '[D]ocker: compose [l]ogs -f' })

vim.keymap.set('n', '<leader>ds', function()
  in_project_terminal { 'docker', 'compose', 'ps' }
end, { desc = '[D]ocker: compose ps ([s]tatus)' })

vim.keymap.set('n', '<leader>dp', function()
  local dir, file = compose_project()
  if not dir then
    vim.notify('No compose file above this buffer', vim.log.levels.WARN)
  else
    vim.notify('compose project: ' .. dir .. '\n  ' .. file, vim.log.levels.INFO)
  end
end, { desc = '[D]ocker: which [p]roject is this file in?' })
