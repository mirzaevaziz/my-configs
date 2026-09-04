-- flash.nvim -- jump to any visible location by typing a couple of characters,
-- then pressing the label that appears next to the match.
--
-- Restored from the pre-kickstart config at ~/.config/nvim.bak-20260904.
-- Same five mappings as before, so the muscle memory carries over.

vim.pack.add { 'https://github.com/folke/flash.nvim' }

require('flash').setup {
  modes = {
    -- Char mode is what would hook into f/F/t/T and extend them. It stays off,
    -- as it was in the old config, so `t`/`T` remain exactly stock vim.
    char = { enabled = false },
  },
}

local flash = require 'flash'

-- NOTE: this shadows the native `f{char}` motion. That was true of the old
-- config too, so it is deliberate -- but if you ever want native `f` back,
-- change the lhs below from 'f' to 's' and nothing else needs to move.
vim.keymap.set({ 'n', 'x', 'o' }, 'f', function() flash.jump() end, { desc = 'Flash jump' })
vim.keymap.set({ 'n', 'x', 'o' }, 'F', function() flash.treesitter() end, { desc = 'Flash treesitter node' })
vim.keymap.set('o', 'r', function() flash.remote() end, { desc = 'Remote flash (operate at a distance)' })
vim.keymap.set({ 'o', 'x' }, 'R', function() flash.treesitter_search() end, { desc = 'Flash treesitter search' })
vim.keymap.set('c', '<C-s>', function() flash.toggle() end, { desc = 'Toggle flash in / search' })
