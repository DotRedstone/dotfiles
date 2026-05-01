# ---
# Module: NixVim - LSP Plugins
# Description: Language Server Protocol configuration and related tools
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.plugins = {
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
            diagnostics.globals = [ "vim" "Snacks" ];
          };
        };
        marksman.enable = true;
        tinymist = {
          enable = true;
          settings = {
            autoArchive = true;
            formatterMode = "typstyle";
            exportPdf = "onSave";
            semanticTokens = "disable";
          };
        };
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

    lazydev = {
      enable = true;
      settings.library = [
        { path = "luvit-meta/library"; words = [ "vim%.uv" ]; }
      ];
    };

    trouble.enable = true;
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
    venv-selector.enable = true;
    vim-dadbod.enable = true;
    vim-dadbod-ui.enable = true;
    vim-dadbod-completion.enable = true;
  };

  programs.nixvim.keymaps = [
    { mode = "n"; key = "gd"; action = "<cmd>lua vim.lsp.buf.definition()<cr>"; options.desc = "Goto definition"; }
    { mode = "n"; key = "gD"; action = "<cmd>lua vim.lsp.buf.declaration()<cr>"; options.desc = "Goto declaration"; }
    { mode = "n"; key = "gr"; action = "<cmd>lua vim.lsp.buf.references()<cr>"; options.desc = "References"; }
    { mode = "n"; key = "gI"; action = "<cmd>lua vim.lsp.buf.implementation()<cr>"; options.desc = "Goto implementation"; }
    { mode = "n"; key = "gy"; action = "<cmd>lua vim.lsp.buf.type_definition()<cr>"; options.desc = "Goto type definition"; }
    { mode = "n"; key = "K"; action = "<cmd>lua vim.lsp.buf.hover()<cr>"; options.desc = "Hover"; }
    { mode = "n"; key = "<leader>ca"; action = "<cmd>lua vim.lsp.buf.code_action()<cr>"; options.desc = "Code action"; }
    { mode = "n"; key = "<leader>rn"; action = "<cmd>lua vim.lsp.buf.rename()<cr>"; options.desc = "Rename"; }
    { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<cr>"; options.desc = "Diagnostics"; }
    { mode = "n"; key = "<leader>xX"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"; options.desc = "Buffer diagnostics"; }
    { mode = "n"; key = "<leader>cs"; action = "<cmd>Trouble symbols toggle focus=false<cr>"; options.desc = "Symbols"; }
    { mode = "n"; key = "<leader>cl"; action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>"; options.desc = "LSP definitions / references"; }
    { mode = "n"; key = "<leader>xL"; action = "<cmd>Trouble loclist toggle<cr>"; options.desc = "Location list"; }
    { mode = "n"; key = "<leader>xQ"; action = "<cmd>Trouble qflist toggle<cr>"; options.desc = "Quickfix list"; }
    { mode = "n"; key = "[d"; action = "<cmd>lua vim.diagnostic.goto_prev()<cr>"; options.desc = "Previous diagnostic"; }
    { mode = "n"; key = "]d"; action = "<cmd>lua vim.diagnostic.goto_next()<cr>"; options.desc = "Next diagnostic"; }
    { mode = "n"; key = "<leader>cv"; action = "<cmd>VenvSelect<cr>"; options.desc = "Select Python venv"; }
  ];
}
