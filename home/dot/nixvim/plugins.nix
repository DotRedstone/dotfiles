# ---
# Module: Nixvim Plugins
# Description: Comprehensive plugin set mirroring the full LazyVim experience
# ---

{ ... }: {
  programs.nixvim.plugins = {
    # [UI Enhancements]
    lualine.enable = true;
    bufferline.enable = true;
    neo-tree.enable = true;
    noice.enable = true;
    notify.enable = true;
    web-devicons.enable = true;
    which-key.enable = true;
    indent-blankline.enable = true;
    
    # Dashboard (Replacement for Alpha/Mini.starter)
    alpha = {
      enable = true;
      theme = "dashboard";
    };

    # Better UI components
    dressing.enable = true;
    nui.enable = true;

    # [Search & Navigation]
    telescope = {
      enable = true;
      settings = {
        defaults = {
          layout_strategy = "horizontal";
          layout_config = { prompt_position = "top"; };
          sorting_strategy = "ascending";
          winblend = 0;
        };
      };
      keymaps = {
        "<leader>ff" = "find_files";
        "<leader>fg" = "live_grep";
        "<leader>fb" = "buffers";
        "<leader>fh" = "help_tags";
        "<leader>fp" = {
          action = "find_files";
          options = {
            desc = "Find Project Files";
          };
        };
      };
    };

    flash = {
      enable = true;
      labels = "asdfghjklqwertyuiopzxcvbnm";
    };

    # [Coding & Editing]
    treesitter = {
      enable = true;
      nixGrammars = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        ensure_installed = [
          "bash" "html" "javascript" "json" "lua" "markdown" 
          "python" "tsx" "typescript" "vim" "yaml" "nix"
        ];
      };
    };
    
    # Auto-pairing and commenting
    nvim-autopairs.enable = true;
    comment.enable = true;
    surround.enable = true;
    
    # [LSP & Formatting]
    lsp = {
      enable = true;
      servers = {
        pyright.enable = true;
        ts_ls.enable = true;
        lua_ls.enable = true;
        nil_ls.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "declaration";
        "gr" = "references";
        "gI" = "implementation";
        "K" = "hover";
        "<leader>ca" = "code_action";
        "<leader>rn" = "rename";
        "<leader>cf" = "format";
      };
    };

    # None-ls for formatting/linting (shfmt, shellcheck, etc.)
    none-ls = {
      enable = true;
      sources = {
        formatting = {
          shfmt.enable = true;
          stylua.enable = true;
          prettier.enable = true;
        };
        diagnostics = {
          shellcheck.enable = true;
        };
      };
    };

    # [Autocompletion]
    cmp = {
      enable = true;
      settings = {
        autoEnableSources = true;
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
          { name = "buffer"; }
          { name = "emoji"; }
        ];
        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping.select_next_item()";
          "<S-Tab>" = "cmp.mapping.select_prev_item()";
        };
      };
    };
    
    cmp-emoji.enable = true;
    cmp-nvim-lsp.enable = true;
    luasnip.enable = true;

    # [Utility]
    trouble.enable = true;
    todo-comments.enable = true;
    persistence.enable = true; # Session management
  };

  # Custom keymaps and logic for specific plugins
  programs.nixvim.keymaps = [
    {
      mode = [ "n" "o" ];
      key = "S";
      action = "<cmd>lua require('flash').treesitter()<cr>";
      options.desc = "Flash Treesitter";
    }
    {
      mode = [ "n" "x" "o" ];
      key = "s";
      action = "<cmd>lua require('flash').jump()<cr>";
      options.desc = "Flash";
    }
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Neotree toggle<cr>";
      options.desc = "Toggle Explorer";
    }
  ];
}
