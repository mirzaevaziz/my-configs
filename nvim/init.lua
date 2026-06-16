-- <leader> key
vim.g.mapleader = ' '

-- open config
vim.cmd('nmap <leader>c :e ~/.config/nvim/init.lua<cr>')

-- save
vim.cmd('nmap <leader>s :w<cr>')

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({"git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath})
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({{"Failed to clone lazy.nvim:\n", "ErrorMsg"}, {out, "WarningMsg"},
                           {"\nPress any key to exit..."}}, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
        modes = {
            char = {
                enabled = false -- Disable char mode to avoid overriding f/F/t/T
            }
        }
    },
    keys = {{
        "f",
        mode = {"n", "x", "o"},
        function()
            require("flash").jump()
        end,
        desc = "Flash"
    }, {
        "F",
        mode = {"n", "x", "o"},
        function()
            require("flash").treesitter()
        end,
        desc = "Flash Treesitter"
    }, {
        "r",
        mode = "o",
        function()
            require("flash").remote()
        end,
        desc = "Remote Flash"
    }, {
        "R",
        mode = {"o", "x"},
        function()
            require("flash").treesitter_search()
        end,
        desc = "Treesitter Search"
    }, {
        "<c-s>",
        mode = {"c"},
        function()
            require("flash").toggle()
        end,
        desc = "Toggle Flash Search"
    }}
}, -- Add Treesitter
{
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate", -- Automatically install/update parsers
    event = {"BufReadPost", "BufNewFile"}, -- lazy load for efficiency
    dependencies = {"nvim-treesitter/nvim-treesitter-textobjects", -- Optional text objects
    "JoosepAlviste/nvim-ts-context-commentstring" -- Context-aware comments
    },
    opts = {
        ensure_installed = {"bash", "c", "cpp", "css", "c_sharp", "html", "javascript", "json", "lua", "markdown",
                            "markdown_inline", "python", "query", "rust", "tsx", "typescript", "vim", "yaml"},
        highlight = {
            enable = true, -- Enables syntax highlighting
            additional_vim_regex_highlighting = false -- Disable legacy regex highlighting
        },
        indent = {
            enable = true -- Enables Treesitter-based indentation
        },
        incremental_selection = {
            enable = true, -- Use incremental selection
            keymaps = {
                init_selection = "<c-space>", -- Start selection
                node_incremental = "<c-space>", -- Increment to the next node
                scope_incremental = "<c-s>", -- Increment to the scope
                node_decremental = "<M-space>" -- Decrement selection
            }
        },
        textobjects = {
            select = {
                enable = true,
                lookahead = true, -- Automatically jump forward to text objects
                keymaps = {
                    ["af"] = "@function.outer", -- Around a function
                    ["if"] = "@function.inner", -- Inside a function
                    ["ac"] = "@class.outer", -- Around a class
                    ["ic"] = "@class.inner" -- Inside a class
                }
            }
        }
    }
})

-- paste without overwriting
vim.keymap.set('v', 'p', 'P')

-- redo
vim.keymap.set('n', 'U', '<C-r>')

-- clear search highlighting
vim.keymap.set('n', '<leader><Esc>', ':nohlsearch<cr>', {
    desc = "Clear search highlighting"
})

-- skip folds (down, up)
vim.cmd('nmap j gj')
vim.cmd('nmap k gk')

-- sync system clipboard
vim.opt.clipboard = 'unnamedplus'

-- search ignoring case
vim.opt.ignorecase = true

-- disable "ignorecase" option if the search pattern contains upper case characters
vim.opt.smartcase = true

vim.opt.termguicolors = true

if vim.g.vscode then
    -- Navigate errors using VS Code commands
    vim.keymap.set('n', ']d', '<Cmd>call VSCodeNotify("editor.action.marker.nextInFiles")<CR>')
    vim.keymap.set('n', '[d', '<Cmd>call VSCodeNotify("editor.action.marker.prevInFiles")<CR>')

    -- Alternative: Next/Previous in current file only
    vim.keymap.set('n', ']e', '<Cmd>call VSCodeNotify("editor.action.marker.next")<CR>')
    vim.keymap.set('n', '[e', '<Cmd>call VSCodeNotify("editor.action.marker.prev")<CR>')

    -- Open problems panel
    vim.keymap.set('n', '<leader>q', '<Cmd>call VSCodeNotify("workbench.actions.view.problems")<CR>')

    -- Quick fix
    vim.keymap.set('n', '<leader>ca', '<Cmd>call VSCodeNotify("editor.action.quickFix")<CR>')

    -- Focus the Primary Side Bar
    vim.keymap.set('n', '<leader>b', '<Cmd>call VSCodeNotify("workbench.action.focusPrimarySideBar")<CR>', {
        desc = "Focus Primary Side Bar"
    })

    -- Toggle the Primary Side Bar
    vim.keymap.set('n', '<leader>t', '<Cmd>call VSCodeNotify("workbench.action.toggleSidebarVisibility")<CR>', {
        desc = "Toggle Primary Side Bar"
    })

    -- Focus Explorer
    vim.keymap.set('n', '<leader>e', '<Cmd>call VSCodeNotify("workbench.view.explorer")<CR>', {
        desc = "Focus Explorer"
    })

    -- Focus Search
    vim.keymap.set('n', '<leader>f', '<Cmd>call VSCodeNotify("workbench.view.search")<CR>', {
        desc = "Focus Search"
    })

    -- Focus Source Control
    vim.keymap.set('n', '<leader>g', '<Cmd>call VSCodeNotify("workbench.view.scm")<CR>', {
        desc = "Focus Source Control"
    })

    -- Focus Extensions
    vim.keymap.set('n', '<leader>x', '<Cmd>call VSCodeNotify("workbench.view.extensions")<CR>', {
        desc = "Focus Extensions"
    })

    -- Replace gd with go to implementation
    vim.keymap.set('n', 'gd', function()
        vim.fn.VSCodeNotify('editor.action.goToImplementation')
    end, {
        desc = "Go to Implementation"
    })

    -- gD shows implementations in peek window
    vim.keymap.set('n', 'gD', function()
        vim.fn.VSCodeNotify('editor.action.peekImplementation')
    end, {
        desc = "Peek All Implementations"
    })

    -- === SPLIT EDITOR NAVIGATION ===

    -- Focus specific editor groups
    vim.keymap.set('n', '<leader>h', function()
        vim.fn.VSCodeNotify('workbench.action.focusFirstEditorGroup')
    end, {
        desc = "Focus left editor"
    })

    vim.keymap.set('n', '<leader>l', function()
        vim.fn.VSCodeNotify('workbench.action.focusSecondEditorGroup')
    end, {
        desc = "Focus right editor"
    })

    vim.keymap.set('n', '<leader>k', function()
        vim.fn.VSCodeNotify('workbench.action.focusAboveGroup')
    end, {
        desc = "Focus editor above"
    })

    vim.keymap.set('n', '<leader>j', function()
        vim.fn.VSCodeNotify('workbench.action.focusBelowGroup')
    end, {
        desc = "Focus editor below"
    })
else
    -- === PURE NEOVIM VERSION ===

    -- === SCROLL WITH AUTO-CENTER ===
    vim.keymap.set('n', '<C-d>', function()
        vim.cmd('normal! \004zz')
    end, {
        desc = "Scroll down and center"
    })

    vim.keymap.set('n', '<C-u>', function()
        vim.cmd('normal! \025zz')
    end, {
        desc = "Scroll up and center"
    })

end
