-- Minimal Neovim config using the built-in plugin manager (`vim.pack`)
-- Small, mostly mini.nvim-based setup.
-- Requires Neovim 0.12+

-- -----------------------------------------------------------------------------
-- Leaders
-- -----------------------------------------------------------------------------

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- -----------------------------------------------------------------------------
-- Plugins
-- -----------------------------------------------------------------------------

vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim' },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    name = 'nvim-treesitter',
    version = 'main',
  },
  { src = 'https://github.com/rluba/jai.vim' },
})

vim.api.nvim_create_user_command('PackSync', function(opts)
  local unused = vim.iter(vim.pack.get(nil, { info = false }))
    :filter(function(plugin) return not plugin.active end)
    :map(function(plugin) return plugin.spec.name end)
    :totable()

  if #unused > 0 then
    vim.pack.del(unused)
    vim.notify('Deleted unused plugins: ' .. table.concat(unused, ', '))
  end

  vim.pack.update(nil, { force = opts.bang })
end, {
  bang = true,
  desc = 'Delete unused vim.pack plugins and update managed plugins',
})

-- -----------------------------------------------------------------------------
-- Basic UI and editor options
-- -----------------------------------------------------------------------------

require('mini.basics').setup({
  options = {
    extra_ui = true,
    win_borders = 'single',
  },
  mappings = {
    move_with_alt = true,
  },
})

vim.cmd.colorscheme('catppuccin')

vim.o.relativenumber = true
vim.o.updatetime = 250
vim.o.timeoutlen = 400
vim.o.scrolloff = 8
vim.o.autoread = true
vim.o.clipboard = 'unnamedplus'
vim.o.confirm = true

-- -----------------------------------------------------------------------------
-- Mini.nvim: UI, navigation, and editing modules
-- -----------------------------------------------------------------------------

require('mini.icons').setup()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.files').setup()
require('mini.pick').setup()
require('mini.extra').setup()
require('mini.bracketed').setup()
require('mini.bufremove').setup()
require('mini.pairs').setup()
require('mini.surround').setup()
require('mini.ai').setup()
require('mini.completion').setup()
require('mini.align').setup()

require('mini.diff').setup({
  view = {
    style = 'sign',
    signs = { add = '+', change = '~', delete = '-' },
  },
})

require('mini.jump2d').setup({
  mappings = {
    start_jumping = '<leader>j',
  },
})

require('mini.comment').setup({
  mappings = {
    comment = '',
    comment_line = '<leader>c',
    comment_visual = '<leader>c',
    textobject = '',
  },
})

-- Make mini.icons work for plugins expecting nvim-web-devicons.
MiniIcons.mock_nvim_web_devicons()

-- -----------------------------------------------------------------------------
-- Mini.nvim: highlighted patterns
-- -----------------------------------------------------------------------------

local hipatterns = require('mini.hipatterns')

hipatterns.setup({
  highlighters = {
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
    hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
    todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
    note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})

-- -----------------------------------------------------------------------------
-- Mini.nvim: indentation guides
-- -----------------------------------------------------------------------------

local indentscope = require('mini.indentscope')

indentscope.setup({
  draw = {
    animation = indentscope.gen_animation.none(),
  },
  mappings = {
    goto_top = '',
    goto_bottom = '',
  },
})

-- -----------------------------------------------------------------------------
-- Mini.nvim: keybinding hints
-- -----------------------------------------------------------------------------

local miniclue = require('mini.clue')

miniclue.setup({
  triggers = {
    { mode = 'n', keys = '<leader>' },
    { mode = 'x', keys = '<leader>' },
    { mode = 'n', keys = 'g' },
    { mode = 'x', keys = 'g' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },
    { mode = 'n', keys = 'z' },
    { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '<C-w>' },
  },
  clues = {
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.z(),
  },
})

-- -----------------------------------------------------------------------------
-- Tree-sitter parsers, highlighting, folds, and indentation
-- -----------------------------------------------------------------------------

require('nvim-treesitter').setup({
  install_dir = vim.fn.stdpath('data') .. '/site',
})

local treesitter_langs = {
  'bash',
  'c',
  'cpp',
  'css',
  'html',
  'javascript',
  'json',
  'lua',
  'markdown',
  'markdown_inline',
  'odin',
  'python',
  'query',
  'rust',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

-- Installs missing parsers asynchronously. Run `:TSUpdate` after `:packupdate`.
require('nvim-treesitter').install(treesitter_langs)

local treesitter_filetypes = {
  'bash',
  'c',
  'cpp',
  'css',
  'html',
  'javascript',
  'json',
  'lua',
  'markdown',
  'odin',
  'python',
  'query',
  'rust',
  'typescript',
  'typescriptreact',
  'vim',
  'vimdoc',
  'yaml',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = treesitter_filetypes,
  callback = function(args)
    -- Highlighting is built into Neovim 0.12+. nvim-treesitter only installs
    -- parsers and provides queries.
    pcall(vim.treesitter.start, args.buf)

    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldlevel = 99
  end,
})

-- -----------------------------------------------------------------------------
-- Tree-sitter incremental selection
-- -----------------------------------------------------------------------------

local ts_select_state = {}

local get_ts_node = function()
  local ok, node = pcall(vim.treesitter.get_node)
  return ok and node or nil
end

local node_range = function(node)
  local sr, sc, er, ec = node:range()
  if ec > 0 then return sr, sc, er, ec - 1 end

  er = math.max(sr, er - 1)
  local line = vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or ''
  return sr, sc, er, math.max(0, #line - 1)
end

local select_range = function(range)
  local sr, sc, er, ec = unpack(range)
  vim.cmd('normal! \27')
  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { er + 1, ec })
end

_G.ts_selection_expand = function()
  local win = vim.api.nvim_get_current_win()
  local mode = vim.fn.mode()
  local is_visual = mode == 'v' or mode == 'V' or mode == '\22'
  local state = is_visual and ts_select_state[win] or nil
  local node = state and state.node or get_ts_node()
  if node == nil then return end

  if state ~= nil then
    local parent = node:parent()
    if parent ~= nil then node = parent end
  end

  local range = { node_range(node) }
  ts_select_state[win] = { node = node, stack = state and state.stack or {} }
  table.insert(ts_select_state[win].stack, range)
  select_range(range)
end

_G.ts_selection_shrink = function()
  local win = vim.api.nvim_get_current_win()
  local state = ts_select_state[win]
  if state == nil or #state.stack <= 1 then return end

  table.remove(state.stack)
  local range = state.stack[#state.stack]
  local node = get_ts_node()
  while node ~= nil do
    local candidate = { node_range(node) }
    if vim.deep_equal(candidate, range) then break end
    node = node:parent()
  end
  state.node = node or state.node
  select_range(range)
end

-- -----------------------------------------------------------------------------
-- Auto-reload files changed outside Neovim
-- -----------------------------------------------------------------------------

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      vim.cmd('checktime')
    end
  end,
})

-- -----------------------------------------------------------------------------
-- Terminal helper
-- -----------------------------------------------------------------------------

local hide_toggle_terminal_buffer = function(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- Keep toggle terminals out of :buffers, MiniPick buffers, and mini.tabline.
    vim.bo[buf].buflisted = false
  end
end

local toggle_terminal_window = function(buf_var, open_cmd, setup_win)
  local buf = vim.g[buf_var]
  hide_toggle_terminal_buffer(buf)

  if buf and vim.api.nvim_buf_is_valid(buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_close(win, true)
        return
      end
    end
  end

  vim.cmd(open_cmd)
  setup_win()

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_win_set_buf(0, buf)
  else
    vim.cmd('terminal')
    vim.g[buf_var] = vim.api.nvim_get_current_buf()
    hide_toggle_terminal_buffer(vim.g[buf_var])
  end

  vim.cmd('startinsert')
end

_G.toggle_terminal = function()
  toggle_terminal_window('toggle_terminal_buf', 'botright 12split', function()
    vim.cmd('setlocal winfixheight')
  end)
end

_G.toggle_side_terminal = function()
  local width = math.max(50, math.floor(vim.o.columns * 0.40))
  toggle_terminal_window('toggle_side_terminal_buf', 'botright ' .. width .. 'vsplit', function()
    vim.cmd('setlocal winfixwidth')
  end)
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------

local map = vim.keymap.set

-- Completion navigation. Use <C-Space> to open completion menu.
map('i', '<Tab>', [[pumvisible() ? "\<C-n>" : "\<Tab>"]], { expr = true, desc = 'Next completion item' })
map('i', '<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], { expr = true, desc = 'Previous completion item' })

-- Tree-sitter selection.
map({ 'n', 'x' }, '<M-o>', ts_selection_expand, { desc = 'Expand tree-sitter selection' })
map('x', '<M-i>', ts_selection_shrink, { desc = 'Shrink tree-sitter selection' })

-- Terminal.
-- Keep terminal buffers in insert mode when entering them. If a terminal is in
-- terminal-normal mode, <Space> is interpreted as the leader key and waits for
-- `timeoutlen`, which can feel like a short pause while typing.
vim.api.nvim_create_autocmd({ 'TermOpen', 'BufEnter', 'WinEnter' }, {
  pattern = 'term://*',
  callback = function()
    vim.cmd('startinsert')
  end,
})

map('t', '<Space>', '<Space>', { nowait = true, desc = 'Send literal space' })
map('n', '<C-`>', toggle_terminal, { desc = 'Toggle bottom terminal' })
map('t', '<C-`>', '<C-\\><C-n><cmd>lua toggle_terminal()<cr>', { desc = 'Toggle bottom terminal' })
map('n', '<C-a>', toggle_side_terminal, { desc = 'Toggle side terminal' })
map('t', '<C-a>', '<C-\\><C-n><cmd>lua toggle_side_terminal()<cr>', { desc = 'Toggle side terminal' })

-- Files, pickers, buffers, and common commands.
map('n', '<leader>uw', function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = 'Toggle line wrap' })
map('n', '<leader>ur', '<cmd>source ~/.config/nvim/init.lua<cr>', { desc = 'Reload Neovim config' })
map('n', '<leader>uH', '<cmd>checkhealth<cr>', { desc = 'Check health' })
map('n', '<leader>e', MiniFiles.open, { desc = 'File explorer' })
map('n', '<leader>E', function()
  MiniFiles.open(vim.api.nvim_buf_get_name(0), false)
end, { desc = 'File explorer at current file' })
map('n', '<leader>ff', MiniPick.builtin.files, { desc = 'Find files' })
map('n', '<leader>fg', MiniPick.builtin.grep_live, { desc = 'Live grep' })
map('n', '<leader>fb', MiniPick.builtin.buffers, { desc = 'Find buffers' })
map('n', '<leader>fh', MiniPick.builtin.help, { desc = 'Find help' })
map('n', '<leader>fc', '<cmd>edit ~/.config/nvim/init.lua<cr>', { desc = 'Open Neovim config' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
map('n', '<leader>m', '<cmd>make run<cr>', { desc = 'Make' })
map('n', '<leader>bb', '<cmd>buffer #<cr>', { desc = 'Alternate buffer' })
map('n', '<C-Tab>', '<cmd>buffer #<cr>', { desc = 'Alternate buffer' })
map('n', '<leader>bd', MiniBufremove.delete, { desc = 'Delete buffer' })
map('n', '<leader>bD', function() MiniBufremove.delete(0, true) end, { desc = 'Force delete buffer' })
map('n', '<leader>go', MiniDiff.toggle_overlay, { desc = 'Toggle diff overlay' })

-- Windows.
map('n', '<leader>ww', '<cmd>wincmd w<cr>', { desc = 'Next window' })
map('n', '<leader>wh', '<cmd>wincmd h<cr>', { desc = 'Window left' })
map('n', '<leader>wj', '<cmd>wincmd j<cr>', { desc = 'Window down' })
map('n', '<leader>wk', '<cmd>wincmd k<cr>', { desc = 'Window up' })
map('n', '<leader>wl', '<cmd>wincmd l<cr>', { desc = 'Window right' })
map('n', '<leader>ws', '<cmd>split<cr>', { desc = 'Split window' })
map('n', '<leader>wv', '<cmd>vsplit<cr>', { desc = 'Vertical split' })
map('n', '<leader>wq', '<cmd>close<cr>', { desc = 'Close window' })
map('n', '<leader>wo', '<cmd>only<cr>', { desc = 'Only window' })
map('n', '<leader>w=', '<cmd>wincmd =<cr>', { desc = 'Equalize windows' })

-- Quickfix.
local qf_next = function()
  local ok = pcall(vim.cmd.cnext)
  if not ok then pcall(vim.cmd.cfirst) end
end

local qf_prev = function()
  local ok = pcall(vim.cmd.cprev)
  if not ok then pcall(vim.cmd.clast) end
end

map('n', ']q', qf_next, { desc = 'Next quickfix item' })
map('n', '[q', qf_prev, { desc = 'Previous quickfix item' })

-- Diagnostics.
local diagnostics_to_qflist = function()
  vim.diagnostic.setqflist({ open = true })
end

map('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Line diagnostic' })
map('n', '<leader>D', diagnostics_to_qflist, { desc = 'Diagnostics to quickfix' })

-- -----------------------------------------------------------------------------
-- LSP keymaps, formatting, and commands
-- -----------------------------------------------------------------------------

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }
    map('n', 'gd', vim.lsp.buf.definition, opts)
    map('n', 'gr', vim.lsp.buf.references, opts)
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', '<leader>r', vim.lsp.buf.rename, opts)
    map({ 'n', 'x' }, '<leader>a', vim.lsp.buf.code_action, opts)
  end,
})

vim.api.nvim_create_user_command('Format', function()
  vim.lsp.buf.format({ async = true })
end, { desc = 'Format current buffer with LSP' })

vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf })
    local has_formatter = vim.iter(clients):any(function(client)
      return client:supports_method('textDocument/formatting', args.buf)
    end)

    if has_formatter then
      vim.lsp.buf.format({ bufnr = args.buf, async = false, timeout_ms = 1000 })
    end
  end,
})

-- -----------------------------------------------------------------------------
-- LSP servers
-- -----------------------------------------------------------------------------

vim.lsp.config('ty', {
  cmd = { 'ty', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ty.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
  capabilities = MiniCompletion.get_lsp_capabilities(),
})
vim.lsp.enable('ty')

vim.lsp.config('ruff', {
  cmd = { 'ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
  capabilities = MiniCompletion.get_lsp_capabilities(),
})
vim.lsp.enable('ruff')

vim.lsp.config('ols', {
  cmd = { 'ols' },
  filetypes = { 'odin' },
  root_markers = { 'ols.json', '.git' },
  init_options = {
    enable_format = true,
  },
  capabilities = MiniCompletion.get_lsp_capabilities(),
})
vim.lsp.enable('ols')

vim.lsp.config('rust_analyzer', {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
  capabilities = MiniCompletion.get_lsp_capabilities(),
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = true },
      check = { command = 'clippy' },
    },
  },
})
vim.lsp.enable('rust_analyzer')

-- -----------------------------------------------------------------------------
-- Filetype-specific settings
-- -----------------------------------------------------------------------------

-- Jai compiler errors: /path/file.jai:22,5: Error: message
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.jai',
  callback = function()
    vim.opt_local.errorformat = [[%f:%l\,%c: %m]]
  end,
})

-- Odin compiler errors: /path/file.odin(22:5) Syntax Error: message
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.odin',
  callback = function()
    vim.opt_local.errorformat = [[%f(%l:%c) %m,%-G%.%#]]
  end,
})
