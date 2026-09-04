-- Quickfix and location list toggles.
--
-- Neovim keeps two separate lists and they do not share commands:
--   quickfix -- one per session. `:copen` / `:cclose`. Used by gitsigns hunks
--               (<leader>hq, <leader>hQ), :grep, and most plugins.
--   location -- one per window. `:lopen` / `:lclose`. Used by kickstart's
--               <leader>q diagnostics mapping.
-- Closing the wrong one silently does nothing, hence a toggle for each.

--- @param what 'quickfix'|'loclist'
--- @return boolean
local function is_open(what)
  for _, win in ipairs(vim.fn.getwininfo()) do
    if what == 'quickfix' and win.quickfix == 1 and win.loclist == 0 then return true end
    if what == 'loclist' and win.loclist == 1 then return true end
  end
  return false
end

vim.keymap.set('n', '<leader>x', function()
  if is_open 'quickfix' then
    vim.cmd 'cclose'
  else
    -- `:copen` on an empty list errors; say so instead.
    if vim.tbl_isempty(vim.fn.getqflist()) then
      vim.notify('Quickfix list is empty', vim.log.levels.INFO)
    else
      vim.cmd 'copen'
    end
  end
end, { desc = 'Toggle quickfi[x] list' })

vim.keymap.set('n', '<leader>X', function()
  if is_open 'loclist' then
    vim.cmd 'lclose'
  else
    if vim.tbl_isempty(vim.fn.getloclist(0)) then
      vim.notify('Location list is empty', vim.log.levels.INFO)
    else
      vim.cmd 'lopen'
    end
  end
end, { desc = 'Toggle location list' })
