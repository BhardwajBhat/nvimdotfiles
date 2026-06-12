-- Minimal Neovim config using the built-in plugin manager (`vim.pack`)
-- Requires Neovim 0.12+

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Built-in plugin manager
vim.pack.add({
  { src = 'https://github.com/echasnovski/mini.nvim' },
  { src = 'https://github.com/rluba/jai.vim' },
})

-- Mini.nvim modules
require('mini.basics').setup({
  options = {
    extra_ui = true,
    win_borders = 'single',
  },
  mappings = {
    move_with_alt = true,
  },
})

-- Small personal options not covered by mini.basics
vim.o.relativenumber = true
vim.o.updatetime = 250
vim.o.timeoutlen = 400

require('mini.icons').setup()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.files').setup()
require('mini.pick').setup()
require('mini.extra').setup()
require('mini.bracketed').setup()
require('mini.diff').setup()
require('mini.bufremove').setup()

require('mini.jump2d').setup({
  mappings = {
    start_jumping = '<leader>j',
  },
})

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

require('mini.pairs').setup()
require('mini.surround').setup()
require('mini.ai').setup()
require('mini.comment').setup({
  mappings = {
    comment = '',
    comment_line = '<leader>c',
    comment_visual = '<leader>c',
    textobject = '',
  },
})
require('mini.completion').setup()

-- Minimal completion navigation. Use <C-Space> to open completion menu.
vim.keymap.set('i', '<Tab>', [[pumvisible() ? "\<C-n>" : "\<Tab>"]], { expr = true, desc = 'Next completion item' })
vim.keymap.set('i', '<S-Tab>', [[pumvisible() ? "\<C-p>" : "\<S-Tab>"]], { expr = true, desc = 'Previous completion item' })

-- Tree-sitter incremental selection with Alt-o / Alt-i.
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

vim.keymap.set({ 'n', 'x' }, '<M-o>', ts_selection_expand, { desc = 'Expand tree-sitter selection' })
vim.keymap.set('x', '<M-i>', ts_selection_shrink, { desc = 'Shrink tree-sitter selection' })

-- Make mini.icons work for plugins expecting nvim-web-devicons
MiniIcons.mock_nvim_web_devicons()

-- Keymaps
local map = vim.keymap.set

-- Toggleable terminal
_G.toggle_terminal = function()
  local buf = vim.g.toggle_terminal_buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_close(win, true)
        return
      end
    end
  end

  vim.cmd('botright 12split')
  vim.cmd('setlocal winfixheight')

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_win_set_buf(0, buf)
  else
    vim.cmd('terminal')
    vim.g.toggle_terminal_buf = vim.api.nvim_get_current_buf()
  end

  vim.cmd('startinsert')
end

map('n', '<leader>t', toggle_terminal, { desc = 'Toggle terminal' })
map('t', '<leader>t', '<C-\\><C-n><cmd>lua toggle_terminal()<cr>', { desc = 'Toggle terminal' })

map('n', '<leader>e', MiniFiles.open, { desc = 'File explorer' })
map('n', '<leader>E', function()
  MiniFiles.open(vim.api.nvim_buf_get_name(0), false)
end, { desc = 'File explorer at current file' })
map('n', '<leader>ff', MiniPick.builtin.files, { desc = 'Find files' })
map('n', '<leader>fg', MiniPick.builtin.grep_live, { desc = 'Live grep' })
map('n', '<leader>fb', MiniPick.builtin.buffers, { desc = 'Find buffers' })
map('n', '<leader>fh', MiniPick.builtin.help, { desc = 'Find help' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
map('n', '<leader>m', '<cmd>make<cr><cmd>copen<cr>', { desc = 'Make and open quickfix' })
map('n', '<leader>bd', MiniBufremove.delete, { desc = 'Delete buffer' })
map('n', '<leader>bD', function() MiniBufremove.delete(0, true) end, { desc = 'Force delete buffer' })
map('n', '<leader>go', MiniDiff.toggle_overlay, { desc = 'Toggle diff overlay' })

-- Window commands
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

-- Quickfix navigation
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

-- Diagnostics
map('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Line diagnostic' })

-- LSP defaults: when a language server attaches, add common keymaps.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }
    map('n', 'gd', vim.lsp.buf.definition, opts)
    map('n', 'gr', vim.lsp.buf.references, opts)
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', '<leader>r', vim.lsp.buf.rename, opts)
    map({ 'n', 'x' }, '<leader>a', vim.lsp.buf.code_action, opts)
    map('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, opts)
  end,
})

-- LSP servers
vim.lsp.config('ols', {
  cmd = { 'ols' },
  filetypes = { 'odin' },
  root_markers = { 'ols.json', 'odin.json', '.git' },
})
vim.lsp.enable('ols')

-- Jai compiler errors: /path/file.jai:22,5: Error: message
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.jai',
  callback = function()
    vim.opt_local.errorformat = [[%f:%l\,%c: %m]]
  end,
})

-- External formatters. Add more filetypes here as needed.
local formatters = {
  odin = { 'odinfmt', '-stdin' },
}

vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function()
    local cmd = formatters[vim.bo.filetype]
    if cmd == nil then return end

    if vim.fn.executable(cmd[1]) == 0 then
      vim.notify(cmd[1] .. ' not found', vim.log.levels.WARN, { title = 'formatter' })
      return
    end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local input = table.concat(lines, '\n') .. '\n'
    local output = vim.fn.system(cmd, input)

    if vim.v.shell_error ~= 0 then
      vim.notify(output, vim.log.levels.ERROR, { title = cmd[1] .. ' failed' })
      return
    end

    local formatted = vim.split(output, '\n', { plain = true })
    if formatted[#formatted] == '' then table.remove(formatted) end

    local view = vim.fn.winsaveview()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, formatted)
    vim.fn.winrestview(view)
  end,
})
