-- Markdown reading setup: in-buffer rendering with inline images, plus a
-- browser preview for the cases the terminal cannot draw (mermaid, math).
--
-- Buffers open as plain markdown source. <leader>mv flips to the rendered
-- view, <leader>mp opens the real thing in a browser.

vim.pack.add {
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/iamcco/markdown-preview.nvim',
}

require('render-markdown').setup {
  file_types = { 'markdown' },
  enabled = false,
}

-- snacks is a bundle; only the image module is wanted here. Ghostty speaks the
-- kitty graphics protocol, so images land inline in the buffer.
require('snacks').setup {
  image = { enabled = true },
}

-- Setup above had to run with images enabled so snacks installs its FileType
-- hook; flipping the flag afterwards is what leaves buffers opening as source.
Snacks.image.config.enabled = false

-- markdown-preview runs from its bundled node app, built once with
--   cd .../markdown-preview.nvim/app && yarn install
-- The upstream prebuilt binary is unsigned and macOS refuses to exec it
-- (E903: Unknown system error -88), so do not let `mkdp#util#install()` put a
-- `app/bin/` back -- its presence takes priority over the node path.
vim.g.mkdp_theme = 'dark'
vim.g.mkdp_auto_close = 1

local view = false

local function show_images(buf)
  Snacks.image.config.enabled = true
  require('snacks.image.doc').attach(buf)
end

local function hide_images()
  Snacks.image.config.enabled = false
  require('snacks.image.placement').clean()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- The inline renderer redraws on its own autocmds, so the group has to go
    -- or the images it just cleaned come straight back.
    pcall(vim.api.nvim_del_augroup_by_name, 'snacks.image.inline.' .. buf)
    if vim.api.nvim_buf_is_valid(buf) then
      vim.b[buf].snacks_image_attached = false
    end
  end
end

local function toggle_view()
  view = not view
  require('render-markdown').toggle()
  if view then
    show_images(vim.api.nvim_get_current_buf())
  else
    hide_images()
  end
end

vim.keymap.set('n', '<leader>mv', toggle_view, { desc = '[M]arkdown [v]iew toggle' })
vim.keymap.set('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', { desc = '[M]arkdown browser [p]review' })

return { toggle_view = toggle_view }
