-- Keep the cursor centred when scrolling by half pages.
--
-- Plain <C-d>/<C-u> leave the cursor wherever it lands, which is often near the
-- top or bottom edge and hard to track. Appending `zz` re-centres the line after
-- the scroll, so your eye stays in one place on screen.
--
-- These are non-recursive (vim.keymap.set defaults to remap = false), so the
-- <C-d> inside the right-hand side is the built-in scroll, not this mapping.

vim.keymap.set({ 'n', 'x' }, '<C-d>', '<C-d>zz', { desc = 'Half page down, centred' })
vim.keymap.set({ 'n', 'x' }, '<C-u>', '<C-u>zz', { desc = 'Half page up, centred' })

-- Same problem, different key: `n` often drops a match on the very bottom row
-- with no context around it. `zz` re-centres, and `zv` opens any fold the match
-- happens to be buried inside.
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search match, centred' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous search match, centred' })
