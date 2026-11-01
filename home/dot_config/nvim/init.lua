-- ========================================================================== --
--  NEOVIM CONFIG: LSP, linting, formatting, file tree, git, "flash" navigation
--  AI lives outside the editor (pi in a herdr pane). Tools install themselves via
--  mason where their runtime exists (npm-based servers only if npm is installed).
-- ========================================================================== --

-- 1. ⚙️  CORE SETTINGS
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Line Numbers & Visuals
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Relative line numbers (easy jumping)
vim.opt.cursorline = true     -- Highlight current line
vim.opt.termguicolors = true  -- True color support
vim.opt.wrap = false          -- Disable line wrapping
vim.opt.scrolloff = 8         -- Keep 8 lines context when scrolling
vim.opt.signcolumn = "yes"    -- Always show gutter (for git/lint signs)
vim.opt.autoread = true        -- Auto-reload files changed externally (e.g. by opencode)

-- Auto-detect file changes when switching panes or moving cursor
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold"}, {
  command = "silent! checktime",
})

-- Treat .conf files as ini for syntax highlighting
vim.filetype.add({ extension = { conf = "ini" } })

-- Git root of a path, without spawning git (vim.fs.root walks up looking for .git)
local function find_git_root(path)
  if not path or path == "" then return nil end
  return vim.fs.root(path, ".git")
end

-- Remember the last git root (for external tools) and cd into it
local git_root_file = vim.fn.stdpath("state") .. "/nvim-git-root"
local function update_git_root(root)
  if not root then return end
  if root ~= vim.fn.getcwd() then
    vim.cmd("cd " .. vim.fn.fnameescape(root))
  end
  vim.fn.writefile({root}, git_root_file)
end

-- Auto-cd to git root when opening a file (cached per buffer)
vim.api.nvim_create_autocmd({"BufEnter", "DirChanged"}, {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype ~= "" and vim.bo[buf].filetype ~= "NvimTree" then return end
    local root = vim.b[buf].git_root
    if root == nil and vim.bo[buf].buftype == "" then
      root = find_git_root(vim.api.nvim_buf_get_name(buf)) or false
      vim.b[buf].git_root = root
    end
    update_git_root(root or find_git_root(vim.fn.getcwd()))
  end
})

-- Detect git repo when browsing nvim-tree (cursor on folder = detect repo)
vim.api.nvim_create_autocmd("CursorMoved", {
  pattern = "NvimTree*",
  callback = function()
    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then return end
    local node = api.tree.get_node_under_cursor()
    if not node or not node.absolute_path then return end
    local root = find_git_root(node.absolute_path)
    if root then
      vim.fn.writefile({root}, git_root_file)
    end
  end
})

-- Indentation (2 spaces)
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true

-- System
-- Raw OSC 52 clipboard (no DCS wrap — let herdr intercept and forward to host)
local function osc52_copy(lines, _)
  local text = table.concat(lines, "\n")
  local b64 = vim.base64.encode(text)
  local seq = string.format("\027]52;c;%s\027\\", b64)
  vim.fn.chansend(vim.v.stderr, seq)
end
vim.g.clipboard = {
  name = "OSC 52 (raw)",
  copy = {
    ["+"] = osc52_copy,
    ["*"] = osc52_copy,
  },
  paste = {
    ["+"] = function() return vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') end,
    ["*"] = function() return vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') end,
  },
}
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 250          -- CursorHold/diagnostics delay (50 was needlessly busy)
vim.opt.mouse = "a"               -- Enable mouse support
vim.opt.undofile = true           -- Persistent undo history

-- Auto-open file explorer on startup (handled once in the autocmds section below;
-- kept here only as a note — the actual VimEnter autocmd is defined later with
-- pcall guards).

-- Window borders
vim.opt.fillchars = {
  vert = "█",
  vertleft = "█",
  vertright = "█",
  horiz = "█",
  horizup = "█",
  horizdown = "█",
  verthoriz = "█",
}

-- ========================================================================== --
--  📦 PLUGIN MANAGER (LAZY.NVIM)
-- ========================================================================== --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ========================================================================== --
--  🧩 PLUGINS
-- ========================================================================== --
require("lazy").setup({

  -- 🎨 Theme: Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme "catppuccin"
    end
  },

  -- 📂 File Explorer (Auto-Open configured below)
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-web-devicons").setup({ default = false })
      require("nvim-tree").setup({
        view = {
          width = 30,
          side = "left",
        },
        sync_root_with_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
        git = { enable = true },
        actions = {
          change_dir = { global = true },
          open_file = { quit_on_open = false },
        },
        renderer = {
          highlight_git = "name",
          icons = {
            show = {
              file = false,
              folder_arrow = false,
              git = false,
            },
            glyphs = {
              folder = {
                arrow_closed = "",
                arrow_open = "",
                default = "📁",
                open = "📂",
                empty = "📁",
                empty_open = "📂",
                symlink = "🔗",
                symlink_open = "🔗",
              },
            },
          },
        },
        filters = { dotfiles = false },
      })
      -- Git status colors for nvim-tree filenames
      vim.api.nvim_set_hl(0, "NvimTreeGitNewHL", { fg = "#a6e3a1" })       -- new/untracked: green
      vim.api.nvim_set_hl(0, "NvimTreeGitDirtyHL", { fg = "#f9e2af" })     -- modified: yellow
      vim.api.nvim_set_hl(0, "NvimTreeGitStagedHL", { fg = "#a6e3a1" })    -- staged: green
      vim.api.nvim_set_hl(0, "NvimTreeGitDeletedHL", { fg = "#f38ba8" })   -- deleted: red
      vim.api.nvim_set_hl(0, "NvimTreeGitMergeHL", { fg = "#fab387" })     -- merge conflict: orange
      vim.api.nvim_set_hl(0, "NvimTreeGitRenamedHL", { fg = "#89dceb" })   -- renamed: cyan
      vim.api.nvim_set_hl(0, "NvimTreeGitIgnoredHL", { fg = "#585b70" })   -- ignored: dim
      -- Match tree background to editor (catppuccin mocha "base")
      vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#1e1e2e" })
      vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "#1e1e2e" })
      vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { bg = "#1e1e2e", fg = "#1e1e2e" })
      vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { bg = "#1e1e2e", fg = "#1e1e2e" })
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = "Toggle Explorer" })
    end
  },

  -- 📊 Status Line
  {
    'nvim-lualine/lualine.nvim',
    opts = { options = { theme = 'catppuccin-mocha' } }  -- plugin renamed 'catppuccin'
  },

-- Syntax Highlighting (Treesitter, `main` branch API)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local parsers = { "lua", "python", "bash", "dockerfile", "json", "yaml", "markdown", "markdown_inline",
                        "ini", "toml", "vim", "vimdoc", "regex" }
      -- the main branch compiles parsers with the tree-sitter CLI; skip quietly where it isn't installed
      if vim.fn.executable("tree-sitter") == 1 then require("nvim-treesitter").install(parsers) end
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          -- start highlighting whenever a parser exists for the buffer's language
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end
  },

  -- 🛤️ Indentation Guides (Rainbow Lines)
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },

  -- 🔍 Fuzzy Finder (Telescope)
  {
    'nvim-telescope/telescope.nvim', branch = 'master',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = "Find Files" })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = "Search Text" })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = "Find Buffers" })
    end
  },

  -- ⚡ "Flash" Navigation (Teleport)
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
    },
  },

  -- 🐙 Git Integration (Signs + Fugitive)
  {
    "lewis6991/gitsigns.nvim", -- Gutter signs
    config = function()
      require('gitsigns').setup({
        signs = {
          add          = { text = '▎' },
          change       = { text = '▎' },
          delete       = { text = '▁' },
          topdelete    = { text = '▔' },
          changedelete = { text = '▎' },
        },
      })
      -- Catppuccin Mocha git sign colors
      vim.api.nvim_set_hl(0, "GitSignsAdd",          { fg = "#a6e3a1" })
      vim.api.nvim_set_hl(0, "GitSignsChange",       { fg = "#f9e2af" })
      vim.api.nvim_set_hl(0, "GitSignsDelete",       { fg = "#f38ba8" })
      vim.api.nvim_set_hl(0, "GitSignsTopdelete",    { fg = "#f38ba8" })
      vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = "#f9e2af" })
    end
  },
  {
    "tpope/vim-fugitive",      -- Git commands
    config = function() vim.keymap.set("n", "<leader>gs", vim.cmd.Git) end
  },

  -- 🤖 AI: no in-editor plugin; pi runs in a herdr pane next to nvim.
  -- Markdown rendering (was a dependency of the removed opencode.nvim)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "markdown" },
    opts = { anti_conceal = { enabled = false } },
  },

  -- 🛠️ LSP, LINTING, FORMATTING (The "IDE" Core)
  -- 1. Mason (installs language servers)
  { "mason-org/mason.nvim", opts = {} },

  -- 2. LSP (nvim 0.11+ native config; mason-lspconfig v2 enables every installed server)
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      -- stylua is a formatter here (conform), not a second Lua language server
      require("mason-lspconfig").setup({ automatic_enable = { exclude = { "stylua" } } })
    end
  },

  -- 2b. Install LSPs/formatters/linters automatically (only what the machine can run)
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    config = function()
      -- standalone binaries: work everywhere
      local tools = { "lua-language-server", "ruff", "stylua", "shellcheck", "shfmt", "hadolint" }
      -- node-based servers/formatters only where npm exists (desktops; the server stays lean)
      if vim.fn.executable("npm") == 1 then
        vim.list_extend(tools, { "pyright", "bash-language-server", "dockerfile-language-server",
                                 "yaml-language-server", "json-lsp", "prettier" })
      end
      -- codespell is a pip package: needs python3 with venv support
      if vim.fn.executable("python3") == 1 and vim.fn.executable("npm") == 1 then table.insert(tools, "codespell") end
      require("mason-tool-installer").setup({ ensure_installed = tools, run_on_start = true })
    end
  },

  -- 3. Formatting (Auto-format on Save)
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        javascript = { "prettier" },
        sh = { "shfmt" },     -- filetype is "sh" for bash scripts too
        bash = { "shfmt" },
      },
      format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
    },
  },

  -- 4. Linting (Error checking)
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        -- python: ruff runs as an LSP (no second ruff here, it would duplicate diagnostics)
        dockerfile = { "hadolint" },
        sh = { "shellcheck" },
        -- spelling as diagnostics only (never rewrites code)
        markdown = { "codespell" },
        text = { "codespell" },
      }
      -- Auto-trigger linting, only with linters that are installed (no ENOENT noise on new machines)
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        callback = function()
          local names = vim.tbl_filter(function(name)
            local l = lint.linters[name]
            local cmd = type(l) == "function" and l().cmd or (l and l.cmd)
            return type(cmd) == "string" and vim.fn.executable(cmd) == 1
          end, lint.linters_by_ft[vim.bo.filetype] or {})
          if #names > 0 then lint.try_lint(names) end
        end,
      })
    end
  },

  -- 🧠 Autocompletion (blink.cmp: one plugin instead of nvim-cmp + 5 sources/snippet plugins)
  {
    "saghen/blink.cmp",
    version = "1.*",            -- release tags ship the prebuilt fuzzy matcher
    event = "InsertEnter",
    opts = {
      keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-e>"] = { "hide", "fallback" },
      },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        documentation = { auto_show = true },
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- ⚡ Utilities (Auto-pairs, Surround). Commenting: built-in `gc`/`gcc` (Neovim 0.10+)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {} 
  },
  {
    "kylechui/nvim-surround", -- "ysiw" to surround word
    version = "*",
    event = "VeryLazy",
    config = function() require("nvim-surround").setup({}) end
  },
  {
    "folke/trouble.nvim", -- Error list
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
    },
  },
})

-- ========================================================================== --
--  🕹️  AUTO-COMMANDS & KEYBINDINGS
-- ========================================================================== --

-- 1. Auto-Open File Explorer (SAFE MODE)
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- CRITICAL: Check if we have a UI (prevents crash in headless mode)
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    -- Only open if no file was specified
    if vim.fn.argc() == 0 then
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        api.tree.open()
      end
      -- Focus editor pane
      vim.cmd("wincmd l")
    end
  end
})

-- NOTE: a previous QuitPre -> `bwipeout!` autocmd lived here; it force-wiped the
-- buffer on :q and silently discarded unsaved changes. Removed — plain :q already
-- quits the current buffer/window without losing data.

-- 3. Auto-copy on mouse select (yank to system clipboard on mouse release)
vim.keymap.set('v', '<LeftRelease>', '"+y', { silent = true })

-- 4. Disable horizontal mouse scroll (only up/down)
for _, mode in ipairs({ 'n', 'i', 'v', 'x' }) do
  vim.keymap.set(mode, '<ScrollWheelLeft>', '<Nop>', { silent = true })
  vim.keymap.set(mode, '<ScrollWheelRight>', '<Nop>', { silent = true })
end

-- 5. Window Navigation (Ctrl + h/j/k/l)
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "Left Window" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "Bottom Window" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "Top Window" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "Right Window" })

-- Enhanced Window Splitting Keybindings
vim.keymap.set('n', '<leader>ws', '<C-w>s', { desc = "Split Window Horizontally" })
vim.keymap.set('n', '<leader>wv', '<C-w>v', { desc = "Split Window Vertically" })
vim.keymap.set('n', '<leader>wq', '<C-w>q', { desc = "Quit Window" })
vim.keymap.set('n', '<leader>wo', '<C-w>o', { desc = "Only Window" })
vim.keymap.set('n', '<leader>wn', '<C-w>w', { desc = "Next Window" })
vim.keymap.set('n', '<leader>wp', '<C-w>p', { desc = "Previous Window" })
vim.keymap.set('n', '<leader>wc', '<C-w>c', { desc = "Close Window" })

-- LSP keys. Built in since 0.11: grn rename, gra code action, grr references, gri implementation,
-- K hover, <C-s> signature help (insert). gd is mapped to the LSP definition here.
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go Definition" })