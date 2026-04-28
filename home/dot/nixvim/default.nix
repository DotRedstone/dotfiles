{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tree-sitter
    wl-clipboard

    # Formatters and linters used by conform.nvim / nvim-lint.
    alejandra
    nixfmt-rfc-style
    prettierd
    prettier
    stylua
    shfmt
    shellcheck
    markdownlint-cli
    taplo
    ruff
    black
    isort
    cmake-format
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    withPython3 = true;
    withRuby = false;
    withNodeJs = true;

    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      ripgrep
      fd
      git
      curl
      nodejs
    ];

    globals = {
      mapleader = " ";
      maplocalleader = " ";
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
      markdown_recommended_style = 0;
    };

    opts = {
      # UI
      number = true;
      relativenumber = true;
      termguicolors = true;
      cursorline = true;
      signcolumn = "yes";
      laststatus = 3;
      cmdheight = 0;
      pumblend = 10;
      pumheight = 10;
      winblend = 0;
      scrolloff = 6;
      sidescrolloff = 8;
      conceallevel = 2;
      showmode = false;
      showtabline = 2;
      wrap = false;
      linebreak = true;
      list = true;
      listchars = "tab:  ,trail:.,extends:>,precedes:<,nbsp:+";
      fillchars = "eob: ,fold: ,foldopen:,foldsep: ,foldclose:";

      # Search
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      incsearch = true;
      inccommand = "nosplit";

      # Indentation and formatting
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      expandtab = true;
      smartindent = true;
      shiftround = true;
      breakindent = true;
      formatoptions = "jcroqlnt";

      # Behavior
      mouse = "a";
      autowrite = true;
      confirm = true;
      splitbelow = true;
      splitright = true;
      splitkeep = "screen";
      virtualedit = "block";
      completeopt = "menu,menuone,noselect";
      grepformat = "%f:%l:%c:%m";
      grepprg = "rg --vimgrep";
      jumpoptions = "view";

      # Undo, swap and session
      undofile = true;
      swapfile = false;
      backup = false;
      writebackup = false;
      sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds";

      # Folds
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      # Timing and clipboard
      updatetime = 200;
      timeout = true;
      timeoutlen = 300;
      clipboard = "unnamedplus";
    };

    clipboard.providers.wl-copy.enable = true;

    diagnostic.settings = {
      virtual_text = {
        spacing = 4;
        source = "if_many";
        prefix = "●";
      };
      float = {
        border = "rounded";
        source = "always";
      };
      severity_sort = true;
      signs = {
        text = {
          "__rawKey__vim.diagnostic.severity.ERROR" = "";
          "__rawKey__vim.diagnostic.severity.WARN" = "";
          "__rawKey__vim.diagnostic.severity.HINT" = "";
          "__rawKey__vim.diagnostic.severity.INFO" = "";
        };
      };
    };

    keymaps = [
      {
        mode = "i";
        key = "jk";
        action = "<Esc>";
        options.desc = "Exit insert mode";
      }

      # Mac-style / Super shortcuts. The terminal must pass Super keys through.
      {
        mode = [
          "n"
          "v"
        ];
        key = "<D-c>";
        action = "\"+y";
        options.desc = "Copy to system clipboard";
      }
      {
        mode = "i";
        key = "<D-c>";
        action = "<Esc>\"+ygi";
        options.desc = "Copy to system clipboard";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<D-v>";
        action = "\"+p";
        options.desc = "Paste from system clipboard";
      }
      {
        mode = "i";
        key = "<D-v>";
        action = "<C-r>+";
        options.desc = "Paste from system clipboard";
      }
      {
        mode = [
          "n"
          "v"
          "i"
        ];
        key = "<D-s>";
        action = "<cmd>w<cr>";
        options.desc = "Save file";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<D-a>";
        action = "ggVG";
        options.desc = "Select all";
      }

      # Window management
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options.desc = "Go to left window";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options.desc = "Go to lower window";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options.desc = "Go to upper window";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options.desc = "Go to right window";
      }
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<cr>";
        options.desc = "Increase window height";
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<cr>";
        options.desc = "Decrease window height";
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<cr>";
        options.desc = "Decrease window width";
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<cr>";
        options.desc = "Increase window width";
      }
      {
        mode = "n";
        key = "<leader>-";
        action = "<C-w>s";
        options.desc = "Split window below";
      }
      {
        mode = "n";
        key = "<leader>|";
        action = "<C-w>v";
        options.desc = "Split window right";
      }
      {
        mode = "n";
        key = "<leader>wd";
        action = "<C-w>c";
        options.desc = "Delete window";
      }

      # Buffers
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<cr>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "[b";
        action = "<cmd>bprevious<cr>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "]b";
        action = "<cmd>bnext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<leader>bb";
        action = "<cmd>e #<cr>";
        options.desc = "Switch to other buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>lua Snacks.bufdelete()<cr>";
        options.desc = "Delete buffer";
      }
      {
        mode = "n";
        key = "<leader>bD";
        action = "<cmd>bd!<cr>";
        options.desc = "Delete buffer force";
      }

      # Files and sessions
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options.desc = "Save file";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options.desc = "Quit";
      }
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<cr>";
        options.desc = "Quit all";
      }
      {
        mode = "n";
        key = "<leader>qQ";
        action = "<cmd>qa!<cr>";
        options.desc = "Force quit all";
      }
      {
        mode = "n";
        key = "<leader>qs";
        action = "<cmd>lua require('persistence').load()<cr>";
        options.desc = "Restore session";
      }
      {
        mode = "n";
        key = "<leader>ql";
        action = "<cmd>lua require('persistence').load({ last = true })<cr>";
        options.desc = "Restore last session";
      }
      {
        mode = "n";
        key = "<leader>qd";
        action = "<cmd>lua require('persistence').stop()<cr>";
        options.desc = "Do not save session";
      }

      # Movement and editing
      {
        mode = "n";
        key = "<A-j>";
        action = "<cmd>m .+1<cr>==";
        options.desc = "Move line down";
      }
      {
        mode = "n";
        key = "<A-k>";
        action = "<cmd>m .-2<cr>==";
        options.desc = "Move line up";
      }
      {
        mode = "i";
        key = "<A-j>";
        action = "<esc><cmd>m .+1<cr>==gi";
        options.desc = "Move line down";
      }
      {
        mode = "i";
        key = "<A-k>";
        action = "<esc><cmd>m .-2<cr>==gi";
        options.desc = "Move line up";
      }
      {
        mode = "v";
        key = "<A-j>";
        action = ":m '>+1<cr>gv=gv";
        options.desc = "Move selection down";
      }
      {
        mode = "v";
        key = "<A-k>";
        action = ":m '<-2<cr>gv=gv";
        options.desc = "Move selection up";
      }
      {
        mode = "v";
        key = "<";
        action = "<gv";
        options.desc = "Indent left";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
        options.desc = "Indent right";
      }

      # Search and navigation
      {
        mode = [
          "i"
          "n"
        ];
        key = "<esc>";
        action = "<cmd>noh<cr><esc>";
        options.desc = "Escape and clear hlsearch";
      }
      {
        mode = "n";
        key = "n";
        action = "nzzzv";
        options.desc = "Next search result";
      }
      {
        mode = "n";
        key = "N";
        action = "Nzzzv";
        options.desc = "Previous search result";
      }
      {
        mode = [
          "n"
          "x"
          "o"
        ];
        key = "s";
        action = "<cmd>lua require('flash').jump()<cr>";
        options.desc = "Flash";
      }
      {
        mode = [
          "n"
          "o"
        ];
        key = "S";
        action = "<cmd>lua require('flash').treesitter()<cr>";
        options.desc = "Flash Treesitter";
      }
      {
        mode = "o";
        key = "r";
        action = "<cmd>lua require('flash').remote()<cr>";
        options.desc = "Remote Flash";
      }
      {
        mode = [
          "o"
          "x"
        ];
        key = "R";
        action = "<cmd>lua require('flash').treesitter_search()<cr>";
        options.desc = "Treesitter Search";
      }
      {
        mode = "c";
        key = "<C-s>";
        action = "<cmd>lua require('flash').toggle()<cr>";
        options.desc = "Toggle Flash Search";
      }

      # Snacks, explorer and picker
      {
        mode = "n";
        key = "<leader>,";
        action = "<cmd>lua Snacks.picker.buffers()<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>/";
        action = "<cmd>lua Snacks.picker.grep()<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>:";
        action = "<cmd>lua Snacks.picker.command_history()<cr>";
        options.desc = "Command history";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>lua Snacks.explorer()<cr>";
        options.desc = "Explorer";
      }
      {
        mode = "n";
        key = "<leader>E";
        action = "<cmd>Neotree reveal<cr>";
        options.desc = "Explorer reveal";
      }
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>lua Snacks.picker.files()<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>lua Snacks.picker.grep()<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>fG";
        action = "<cmd>lua Snacks.picker.git_files()<cr>";
        options.desc = "Find git files";
      }
      {
        mode = "n";
        key = "<leader>fr";
        action = "<cmd>lua Snacks.picker.recent()<cr>";
        options.desc = "Recent files";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>lua Snacks.picker.buffers()<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>lua Snacks.picker.help()<cr>";
        options.desc = "Help pages";
      }
      {
        mode = "n";
        key = "<leader>sg";
        action = "<cmd>lua Snacks.picker.grep()<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>sw";
        action = "<cmd>lua Snacks.picker.grep_word()<cr>";
        options.desc = "Word";
      }
      {
        mode = "n";
        key = "<leader>sh";
        action = "<cmd>lua Snacks.picker.help()<cr>";
        options.desc = "Help pages";
      }
      {
        mode = "n";
        key = "<leader>sk";
        action = "<cmd>lua Snacks.picker.keymaps()<cr>";
        options.desc = "Keymaps";
      }
      {
        mode = "n";
        key = "<leader>ss";
        action = "<cmd>lua Snacks.picker.lsp_symbols()<cr>";
        options.desc = "LSP symbols";
      }
      {
        mode = "n";
        key = "<leader>sS";
        action = "<cmd>lua Snacks.picker.lsp_workspace_symbols()<cr>";
        options.desc = "Workspace symbols";
      }
      {
        mode = "n";
        key = "<leader>un";
        action = "<cmd>lua Snacks.notifier.hide()<cr>";
        options.desc = "Dismiss notifications";
      }
      {
        mode = "n";
        key = "<leader>z";
        action = "<cmd>lua Snacks.zen()<cr>";
        options.desc = "Zen mode";
      }

      # Telescope fallback
      {
        mode = "n";
        key = "<leader>fF";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files (Telescope)";
      }
      {
        mode = "n";
        key = "<leader>sG";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Grep (Telescope)";
      }

      # Bufferline
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLineTogglePin<cr>";
        options.desc = "Toggle pin";
      }
      {
        mode = "n";
        key = "<leader>bP";
        action = "<cmd>BufferLineGroupClose ungrouped<cr>";
        options.desc = "Delete non-pinned buffers";
      }
      {
        mode = "n";
        key = "<leader>br";
        action = "<cmd>BufferLineCloseRight<cr>";
        options.desc = "Delete buffers to the right";
      }
      {
        mode = "n";
        key = "<leader>bl";
        action = "<cmd>BufferLineCloseLeft<cr>";
        options.desc = "Delete buffers to the left";
      }
      {
        mode = "n";
        key = "<leader>bo";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options.desc = "Delete other buffers";
      }

      # LSP
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<cr>";
        options.desc = "Goto definition";
      }
      {
        mode = "n";
        key = "gD";
        action = "<cmd>lua vim.lsp.buf.declaration()<cr>";
        options.desc = "Goto declaration";
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>lua vim.lsp.buf.references()<cr>";
        options.desc = "References";
      }
      {
        mode = "n";
        key = "gI";
        action = "<cmd>lua vim.lsp.buf.implementation()<cr>";
        options.desc = "Goto implementation";
      }
      {
        mode = "n";
        key = "gy";
        action = "<cmd>lua vim.lsp.buf.type_definition()<cr>";
        options.desc = "Goto type definition";
      }
      {
        mode = "n";
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<cr>";
        options.desc = "Hover";
      }
      {
        mode = "n";
        key = "<leader>ca";
        action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
        options.desc = "Code action";
      }
      {
        mode = "n";
        key = "<leader>rn";
        action = "<cmd>lua vim.lsp.buf.rename()<cr>";
        options.desc = "Rename";
      }
      {
        mode = "n";
        key = "<leader>cf";
        action = "<cmd>lua require('conform').format({ async = true, lsp_format = 'fallback' })<cr>";
        options.desc = "Format";
      }

      # Diagnostics and Trouble
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options.desc = "Buffer diagnostics";
      }
      {
        mode = "n";
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle focus=false<cr>";
        options.desc = "Symbols";
      }
      {
        mode = "n";
        key = "<leader>cl";
        action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
        options.desc = "LSP definitions / references";
      }
      {
        mode = "n";
        key = "<leader>xL";
        action = "<cmd>Trouble loclist toggle<cr>";
        options.desc = "Location list";
      }
      {
        mode = "n";
        key = "<leader>xQ";
        action = "<cmd>Trouble qflist toggle<cr>";
        options.desc = "Quickfix list";
      }
      {
        mode = "n";
        key = "[d";
        action = "<cmd>lua vim.diagnostic.goto_prev()<cr>";
        options.desc = "Previous diagnostic";
      }
      {
        mode = "n";
        key = "]d";
        action = "<cmd>lua vim.diagnostic.goto_next()<cr>";
        options.desc = "Next diagnostic";
      }

      # Git
      {
        mode = "n";
        key = "<leader>gg";
        action = "<cmd>lua Snacks.lazygit()<cr>";
        options.desc = "Lazygit";
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = "<cmd>lua Snacks.picker.git_branches()<cr>";
        options.desc = "Git branches";
      }
      {
        mode = "n";
        key = "<leader>gc";
        action = "<cmd>lua Snacks.picker.git_log()<cr>";
        options.desc = "Git log";
      }
      {
        mode = "n";
        key = "<leader>gs";
        action = "<cmd>lua Snacks.picker.git_status()<cr>";
        options.desc = "Git status";
      }
      {
        mode = "n";
        key = "<leader>ghb";
        action = "<cmd>Gitsigns blame_line<cr>";
        options.desc = "Blame line";
      }
      {
        mode = "n";
        key = "<leader>ghR";
        action = "<cmd>Gitsigns reset_buffer<cr>";
        options.desc = "Reset buffer";
      }
      {
        mode = "n";
        key = "<leader>ghr";
        action = "<cmd>Gitsigns reset_hunk<cr>";
        options.desc = "Reset hunk";
      }
      {
        mode = "n";
        key = "<leader>ghs";
        action = "<cmd>Gitsigns stage_hunk<cr>";
        options.desc = "Stage hunk";
      }
      {
        mode = "n";
        key = "<leader>ghu";
        action = "<cmd>Gitsigns undo_stage_hunk<cr>";
        options.desc = "Undo stage hunk";
      }

      # Python
      {
        mode = "n";
        key = "<leader>cv";
        action = "<cmd>VenvSelect<cr>";
        options.desc = "Select Python venv";
      }
    ];

    autoCmd = [
      {
        event = "TextYankPost";
        callback.__raw = ''
          function()
            vim.highlight.on_yank({ timeout = 150 })
          end
        '';
      }
      {
        event = "VimResized";
        command = "tabdo wincmd =";
      }
      {
        event = "FileType";
        pattern = [
          "help"
          "man"
          "qf"
          "query"
          "notify"
          "checkhealth"
          "lspinfo"
          "startuptime"
        ];
        callback.__raw = ''
          function(event)
            vim.bo[event.buf].buflisted = false
            vim.keymap.set("n", "q", "<cmd>close<cr>", {
              buffer = event.buf,
              silent = true,
              desc = "Close window",
            })
          end
        '';
      }
      {
        event = "FileType";
        pattern = [
          "gitcommit"
          "markdown"
          "text"
        ];
        callback.__raw = ''
          function()
            vim.opt_local.wrap = true
            vim.opt_local.spell = true
          end
        '';
      }
      {
        event = "BufWritePre";
        callback.__raw = ''
          function(event)
            if vim.bo[event.buf].buftype ~= "" then
              return
            end
            local name = vim.api.nvim_buf_get_name(event.buf)
            if name == "" then
              return
            end
            local dir = vim.fn.fnamemodify(name, ":p:h")
            if vim.fn.isdirectory(dir) == 0 then
              vim.fn.mkdir(dir, "p")
            end
          end
        '';
      }
    ];

    colorschemes.catppuccin.enable = true;

    plugins = {
      # Visual polish
      smear-cursor = {
        enable = true;
        settings = {
          smear_between_buffers = true;
          smear_between_neighbor_lines = true;
          smear_to_cmd = true;
          scroll_buffer_space = true;
          hide_target_hack = true;
          legacy_computing_symbols_support = false;
          stiffness = 0.72;
          trailing_stiffness = 0.38;
          trailing_exponent = 2;
          distance_stop_animating = 0.08;
          time_interval = 17;
          delay_animation_start = 3;
          max_length = 28;
          color_levels = 16;
          cursor_color.__raw = "nil";
          normal_bg.__raw = "nil";
          transparent_bg_fallback_color = "303030";
        };
      };

      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "catppuccin";
            globalstatus = true;
            component_separators = {
              left = "";
              right = "";
            };
            section_separators = {
              left = "";
              right = "";
            };
            disabled_filetypes.statusline = [
              "dashboard"
              "alpha"
              "starter"
            ];
          };
          sections = {
            lualine_a = [
              {
                __unkeyed-1 = "mode";
                separator.right = "";
              }
            ];
            lualine_b = [
              "branch"
              "diff"
            ];
            lualine_c = [
              {
                __unkeyed-1 = "filename";
                path = 1;
                symbols = {
                  modified = " ●";
                  readonly = " ";
                  unnamed = "[No Name]";
                };
              }
            ];
            lualine_x = [
              "diagnostics"
              "encoding"
              "filetype"
            ];
            lualine_y = [ "progress" ];
            lualine_z = [
              {
                __unkeyed-1 = "location";
                separator.left = "";
              }
            ];
          };
        };
      };

      bufferline = {
        enable = true;
        settings.options = {
          diagnostics = "nvim_lsp";
          always_show_bufferline = true;
          separator_style = "slant";
          offsets = [
            {
              filetype = "neo-tree";
              text = "Explorer";
              highlight = "Directory";
              text_align = "left";
            }
          ];
        };
      };

      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          enable_git_status = true;
          enable_diagnostics = true;
          popup_border_style = "rounded";
          filesystem = {
            follow_current_file.enabled = true;
            filtered_items = {
              visible = true;
              hide_dotfiles = false;
              hide_gitignored = false;
            };
          };
        };
      };

      noice = {
        enable = true;
        settings = {
          lsp = {
            override = {
              "vim.lsp.util.convert_input_to_markdown_lines" = true;
              "vim.lsp.util.stylize_markdown" = true;
            };
          };
          presets = {
            bottom_search = true;
            command_palette = true;
            long_message_to_split = true;
            inc_rename = false;
            lsp_doc_border = true;
          };
        };
      };
      notify.enable = true;
      dressing.enable = true;
      nui.enable = true;
      web-devicons.enable = true;
      illuminate.enable = true;
      aerial.enable = true;

      which-key = {
        enable = true;
        settings = {
          preset = "modern";
          delay = 250;
          spec = [
            {
              __unkeyed-1 = "<leader>b";
              group = "buffer";
            }
            {
              __unkeyed-1 = "<leader>c";
              group = "code";
            }
            {
              __unkeyed-1 = "<leader>f";
              group = "file/find";
            }
            {
              __unkeyed-1 = "<leader>g";
              group = "git";
            }
            {
              __unkeyed-1 = "<leader>q";
              group = "quit/session";
            }
            {
              __unkeyed-1 = "<leader>s";
              group = "search/symbols";
            }
            {
              __unkeyed-1 = "<leader>u";
              group = "ui";
            }
            {
              __unkeyed-1 = "<leader>w";
              group = "windows";
            }
            {
              __unkeyed-1 = "<leader>x";
              group = "diagnostics/quickfix";
            }
          ];
        };
      };

      indent-blankline = {
        enable = true;
        settings = {
          indent.char = "│";
          scope = {
            enabled = true;
            show_start = false;
            show_end = false;
          };
          exclude.filetypes = [
            "help"
            "alpha"
            "dashboard"
            "neo-tree"
            "Trouble"
            "lazy"
            "mason"
            "notify"
          ];
        };
      };

      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add.text = "▎";
            change.text = "▎";
            delete.text = "";
            topdelete.text = "";
            changedelete.text = "▎";
            untracked.text = "▎";
          };
          current_line_blame = false;
          current_line_blame_opts.delay = 500;
        };
      };

      snacks = {
        enable = true;
        settings = {
          bigfile.enabled = true;
          dashboard.enabled = false;
          explorer = {
            enabled = true;
            replace_netrw = true;
          };
          input.enabled = true;
          lazygit.enabled = true;
          picker = {
            enabled = true;
            layout.preset = "telescope";
          };
          quickfile.enabled = true;
          rename.enabled = true;
          scroll.enabled = true;
          notifier = {
            enabled = true;
            timeout = 3000;
            style = "compact";
          };
          statuscolumn = {
            enabled = true;
            folds.open = true;
          };
          words = {
            enabled = true;
            debounce = 200;
          };
          zen = {
            enabled = true;
            toggles = {
              dim = false;
              git_signs = false;
              mini_diff_signs = false;
              diagnostics = false;
              inlay_hints = false;
            };
          };
        };
      };

      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        settings.defaults = {
          layout_strategy = "horizontal";
          layout_config.prompt_position = "top";
          sorting_strategy = "ascending";
          winblend = 0;
          border = true;
        };
      };

      flash = {
        enable = true;
        settings = {
          labels = "asdfghjklqwertyuiopzxcvbnm";
          modes.search.enabled = true;
        };
      };

      treesitter = {
        enable = true;
        nixGrammars = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
          ensure_installed = [
            "bash"
            "c"
            "cmake"
            "cpp"
            "css"
            "dockerfile"
            "gitcommit"
            "gitignore"
            "html"
            "java"
            "javascript"
            "json"
            "jsonc"
            "lua"
            "markdown"
            "markdown_inline"
            "nix"
            "python"
            "query"
            "regex"
            "rust"
            "sql"
            "toml"
            "tsx"
            "typescript"
            "vim"
            "vimdoc"
            "vue"
            "yaml"
          ];
        };
      };
      treesitter-textobjects.enable = true;
      ts-autotag.enable = true;
      ts-comments.enable = true;

      mini = {
        enable = true;
        modules = {
          ai = { };
          pairs = { };
          icons = { };
          starter = {
            evaluate_single = true;
            header = ''
               _   _ ________   __     _____ __  __
              | \ | |_   _\ \ / /    _|_   _|  \/  |
              |  \| | | |  \ V /   / \  | | | |\/| |
              | |\  | | |   > <   / _ \ | | | |  | |
              |_| \_|___| /_/ \_\/_/ \_\___|_|  |_|
            '';
            items = [
              {
                name = "Find file";
                action = "lua Snacks.picker.files()";
                section = "Files";
              }
              {
                name = "Recent files";
                action = "lua Snacks.picker.recent()";
                section = "Files";
              }
              {
                name = "Grep text";
                action = "lua Snacks.picker.grep()";
                section = "Search";
              }
              {
                name = "Restore session";
                action = "lua require('persistence').load()";
                section = "Session";
              }
              {
                name = "New file";
                action = "ene | startinsert";
                section = "Builtin";
              }
              {
                name = "Quit";
                action = "qa";
                section = "Builtin";
              }
            ];
          };
        };
      };
      comment.enable = true;
      nvim-surround.enable = true;

      lsp = {
        enable = true;
        inlayHints = true;
        servers = {
          bashls.enable = true;
          clangd.enable = true;
          cmake.enable = true;
          docker_compose_language_service.enable = true;
          dockerls.enable = true;
          jsonls.enable = true;
          lua_ls = {
            enable = true;
            settings = {
              workspace.checkThirdParty = false;
              completion.callSnippet = "Replace";
              diagnostics.globals = [
                "vim"
                "Snacks"
              ];
            };
          };
          marksman.enable = true;
          nil_ls.enable = true;
          pyright.enable = true;
          ruff.enable = true;
          sqls.enable = true;
          tailwindcss.enable = true;
          taplo.enable = true;
          ts_ls.enable = true;
          volar.enable = true;
          yamlls.enable = true;
        };
      };

      schemastore = {
        enable = true;
        json.enable = true;
        yaml.enable = true;
      };

      conform-nvim = {
        enable = true;
        autoInstall.enable = true;
        settings = {
          format_on_save.__raw = ''
            function(bufnr)
              if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                return
              end
              return { timeout_ms = 500, lsp_format = "fallback" }
            end
          '';
          formatters_by_ft = {
            lua = [ "stylua" ];
            nix = [ "nixfmt" ];
            python = [
              "ruff_fix"
              "ruff_format"
              "ruff_organize_imports"
            ];
            sh = [ "shfmt" ];
            bash = [ "shfmt" ];
            zsh = [ "shfmt" ];
            fish = [ "fish_indent" ];
            javascript = [
              "prettierd"
              "prettier"
            ];
            javascriptreact = [
              "prettierd"
              "prettier"
            ];
            typescript = [
              "prettierd"
              "prettier"
            ];
            typescriptreact = [
              "prettierd"
              "prettier"
            ];
            vue = [
              "prettierd"
              "prettier"
            ];
            css = [
              "prettierd"
              "prettier"
            ];
            html = [
              "prettierd"
              "prettier"
            ];
            json = [
              "prettierd"
              "prettier"
            ];
            jsonc = [
              "prettierd"
              "prettier"
            ];
            yaml = [
              "prettierd"
              "prettier"
            ];
            markdown = [
              "prettierd"
              "prettier"
            ];
            toml = [ "taplo" ];
            cmake = [ "cmake_format" ];
          };
          notify_on_error = true;
          notify_no_formatters = false;
        };
      };

      lint = {
        enable = true;
        autoInstall.enable = true;
        lintersByFt = {
          markdown = [ "markdownlint" ];
          sh = [ "shellcheck" ];
          bash = [ "shellcheck" ];
          zsh = [ "shellcheck" ];
          dockerfile = [ "hadolint" ];
        };
      };

      copilot-lua = {
        enable = true;
        settings = {
          suggestion.enabled = false;
          panel.enabled = false;
        };
      };

      blink-copilot.enable = true;
      blink-emoji.enable = true;
      blink-cmp = {
        enable = true;
        setupLspCapabilities = true;
        settings = {
          keymap = {
            preset = "none";
            "<Tab>" = [
              "snippet_forward"
              {
                __raw = ''
                  function(cmp)
                    local is_open = false
                    if cmp.is_menu_visible and cmp.is_menu_visible() then
                      is_open = true
                    else
                      local ok, menu = pcall(require, "blink.cmp.completion.windows.menu")
                      if ok and menu.win and menu.win:is_open() then
                        is_open = true
                      end
                    end

                    if is_open then
                      cmp.select_next()
                      return true
                    end

                    local col = vim.fn.col(".") - 1
                    local has_words = col > 0 and vim.fn.getline("."):sub(col, col):match("%S") ~= nil
                    if has_words then
                      cmp.show()
                      return true
                    end
                  end
                '';
              }
              "fallback"
            ];
            "<S-Tab>" = [
              "snippet_backward"
              "select_prev"
              "fallback"
            ];
            "<Space>" = [
              {
                __raw = ''
                  function(cmp)
                    if cmp.is_menu_visible and cmp.is_menu_visible() then
                      cmp.accept()
                      return true
                    end
                    local ok, menu = pcall(require, "blink.cmp.completion.windows.menu")
                    if ok and menu.win and menu.win:is_open() then
                      cmp.accept()
                      return true
                    end
                  end
                '';
              }
              "fallback"
            ];
            "<CR>" = [ "fallback" ];
          };
          completion = {
            menu = {
              auto_show = false;
              border = "rounded";
            };
            documentation = {
              auto_show = true;
              auto_show_delay_ms = 200;
              window.border = "rounded";
            };
            list.selection = {
              preselect = true;
              auto_insert = false;
            };
            ghost_text.enabled = true;
          };
          signature = {
            enabled = true;
            window.border = "rounded";
          };
          appearance = {
            use_nvim_cmp_as_default = true;
            nerd_font_variant = "normal";
          };
          sources = {
            default = [
              "lsp"
              "path"
              "snippets"
              "buffer"
              "copilot"
              "emoji"
            ];
            providers = {
              copilot = {
                name = "copilot";
                module = "blink-copilot";
                score_offset = 100;
                async = true;
              };
              emoji = {
                name = "emoji";
                module = "blink-emoji";
                score_offset = 15;
              };
            };
          };
        };
      };

      friendly-snippets.enable = true;
      luasnip.enable = true;
      lazydev = {
        enable = true;
        settings.library = [
          {
            path = "luvit-meta/library";
            words = [ "vim%.uv" ];
          }
        ];
      };

      trouble.enable = true;
      todo-comments.enable = true;
      persistence.enable = true;
      grug-far.enable = true;
      render-markdown.enable = true;
      markdown-preview.enable = true;
      crates.enable = true;
      cmake-tools.enable = true;
      venv-selector.enable = true;
      vim-dadbod.enable = true;
      vim-dadbod-ui.enable = true;
      vim-dadbod-completion.enable = true;
      rustaceanvim = {
        enable = true;
        settings.server.default_settings.rust-analyzer = {
          cargo.allFeatures = true;
          check.command = "clippy";
          inlayHints = {
            bindingModeHints.enable = false;
            chainingHints.enable = true;
            closingBraceHints.minLines = 25;
            closureReturnTypeHints.enable = "never";
            lifetimeElisionHints.enable = "never";
            typeHints.enable = true;
          };
        };
      };
      jdtls.enable = true;
    };

    extraConfigLuaPost = ''
      vim.o.winborder = "rounded"

      local function read_noctalia_palette()
        local palette_path = vim.fn.expand("~/.cache/nvim_colors.lua")
        if vim.fn.filereadable(palette_path) == 1 then
          local ok, palette = pcall(dofile, palette_path)
          if ok and type(palette) == "table" then
            return palette
          end
        end
        return {}
      end

      local function detect_system_theme()
        local theme_file = vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json")
        if vim.fn.filereadable(theme_file) ~= 1 then
          return false
        end

        local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(theme_file), "\n"))
        if not ok or type(decoded) ~= "table" or type(decoded.background) ~= "string" then
          return false
        end

        local hex = decoded.background:gsub("#", "")
        if #hex < 6 then
          return false
        end

        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        local brightness = (r * 299 + g * 587 + b * 114) / 1000
        vim.o.background = brightness > 128 and "light" or "dark"
        return true
      end

      local function apply_noctalia_catppuccin()
        local custom_palette = read_noctalia_palette()

        require("catppuccin").setup({
          background = {
            light = "latte",
            dark = "mocha",
          },
          transparent_background = true,
          show_end_of_buffer = false,
          integrations = {
            aerial = true,
            blink_cmp = true,
            flash = true,
            gitsigns = true,
            illuminate = true,
            indent_blankline = {
              enabled = true,
            },
            lsp_trouble = true,
            lualine = true,
            markdown = true,
            mason = false,
            native_lsp = {
              enabled = true,
              virtual_text = {
                errors = { "italic" },
                hints = { "italic" },
                warnings = { "italic" },
                information = { "italic" },
              },
              underlines = {
                errors = { "underline" },
                hints = { "underline" },
                warnings = { "underline" },
                information = { "underline" },
              },
            },
            neotree = true,
            noice = true,
            notify = true,
            snacks = true,
            telescope = {
              enabled = true,
            },
            treesitter = true,
            treesitter_context = true,
            which_key = true,
          },
          color_overrides = {
            all = {
              base = custom_palette.base,
              mantle = custom_palette.mantle,
              crust = custom_palette.crust,
              text = custom_palette.text,
              subtext0 = custom_palette.subtext0,
              subtext1 = custom_palette.subtext1,
              surface0 = custom_palette.surface0,
              surface1 = custom_palette.surface1,
              surface2 = custom_palette.surface2,
              overlay0 = custom_palette.overlay0,
              overlay1 = custom_palette.overlay1,
              overlay2 = custom_palette.overlay2,
              blue = custom_palette.blue,
              cyan = custom_palette.cyan,
              green = custom_palette.green,
              magenta = custom_palette.magenta,
              red = custom_palette.red,
              yellow = custom_palette.yellow,
              rosewater = custom_palette.tertiary,
              flamingo = custom_palette.primary,
              pink = custom_palette.tertiary,
              mauve = custom_palette.primary,
              maroon = custom_palette.error,
              peach = custom_palette.secondary,
              teal = custom_palette.secondary,
              lavender = custom_palette.primary,
            },
          },
        })

        if not detect_system_theme() then
          vim.o.background = "dark"
        end

        vim.cmd.colorscheme(vim.o.background == "light" and "catppuccin-latte" or "catppuccin-mocha")
      end

      apply_noctalia_catppuccin()

      local noctalia_theme_group = vim.api.nvim_create_augroup("dot_noctalia_theme", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = noctalia_theme_group,
        pattern = {
          vim.fn.expand("~/.cache/nvim_colors.lua"),
          vim.fn.expand("~/.local/state/quickshell/user/generated/colors.json"),
        },
        callback = apply_noctalia_catppuccin,
      })

      local lint_group = vim.api.nvim_create_augroup("dot_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = lint_group,
        callback = function()
          require("lint").try_lint()
        end,
      })

      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, {
        desc = "Disable autoformat-on-save",
        bang = true,
      })

      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, {
        desc = "Enable autoformat-on-save",
      })
    '';
  };
}
