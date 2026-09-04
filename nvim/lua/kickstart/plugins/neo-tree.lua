-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

require('neo-tree').setup {
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',

        -- Vim-style folder navigation. Neo-tree does not map these by default:
        -- out of the box `h` is unmapped (so it just moves the cursor) and
        -- `l` is `focus_preview`. These make them behave like a file tree should.
        ['h'] = function(state)
          local node = state.tree:get_node()
          if node.type == 'directory' and node:is_expanded() then
            -- On an open directory: close it.
            require('neo-tree.sources.filesystem').toggle_directory(state, node)
          else
            -- Otherwise: jump up to the parent directory.
            require('neo-tree.ui.renderer').focus_node(state, node:get_parent_id())
          end
        end,

        ['l'] = function(state)
          local node = state.tree:get_node()
          if node.type == 'directory' then
            if not node:is_expanded() then
              -- On a closed directory: open it.
              require('neo-tree.sources.filesystem').toggle_directory(state, node)
            elseif node:has_children() then
              -- Already open: step into the first child.
              require('neo-tree.ui.renderer').focus_node(state, node:get_child_ids()[1])
            end
          else
            -- On a file: open it.
            state.commands.open(state)
          end
        end,
      },
    },
  },
}
