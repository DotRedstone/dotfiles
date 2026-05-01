# ---
# Module: NixVim - Editor Plugins
# Description: General editing enhancements (Snacks, Telescope, Neo-tree, etc.)
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.plugins = {
    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        dashboard.enabled = false;
        explorer = { enabled = true; replace_netrw = true; };
        input.enabled = true;
        lazygit.enabled = true;
        picker = { enabled = true; layout.preset = "telescope"; };
        quickfile.enabled = true;
        rename.enabled = true;
        scroll.enabled = true;
        notifier = { enabled = true; timeout = 3000; style = "compact"; };
        statuscolumn = { enabled = true; folds.open = true; };
        words = { enabled = true; debounce = 200; };
        zen = {
          enabled = true;
          toggles = {
            dim = false; git_signs = false; mini_diff_signs = false;
            diagnostics = false; inlay_hints = false;
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

    neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        enable_git_status = true;
        enable_diagnostics = true;
        popup_border_style = "rounded";
        filesystem = {
          follow_current_file.enabled = true;
          filtered_items = { visible = true; hide_dotfiles = false; hide_gitignored = false; };
        };
      };
    };

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
            { name = "Find file"; action = "lua Snacks.picker.files()"; section = "Files"; }
            { name = "Recent files"; action = "lua Snacks.picker.recent()"; section = "Files"; }
            { name = "Grep text"; action = "lua Snacks.picker.grep()"; section = "Search"; }
            { name = "Restore session"; action = "lua require('persistence').load()"; section = "Session"; }
            { name = "New file"; action = "ene | startinsert"; section = "Builtin"; }
            { name = "Quit"; action = "qa"; section = "Builtin"; }
          ];
        };
      };
    };

    comment.enable = true;
    nvim-surround.enable = true;
    todo-comments.enable = true;
    persistence.enable = true;
    grug-far.enable = true;
  };

  # Keymaps related to these plugins
  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>,"; action = "<cmd>lua Snacks.picker.buffers()<cr>"; options.desc = "Buffers"; }
    { mode = "n"; key = "<leader>/"; action = "<cmd>lua Snacks.picker.grep()<cr>"; options.desc = "Grep"; }
    { mode = "n"; key = "<leader>:"; action = "<cmd>lua Snacks.picker.command_history()<cr>"; options.desc = "Command history"; }
    { mode = "n"; key = "<leader>e"; action = "<cmd>lua Snacks.explorer()<cr>"; options.desc = "Explorer"; }
    { mode = "n"; key = "<leader>E"; action = "<cmd>Neotree reveal<cr>"; options.desc = "Explorer reveal"; }
    { mode = "n"; key = "<leader>ff"; action = "<cmd>lua Snacks.picker.files()<cr>"; options.desc = "Find files"; }
    { mode = "n"; key = "<leader>fg"; action = "<cmd>lua Snacks.picker.grep()<cr>"; options.desc = "Grep"; }
    { mode = "n"; key = "<leader>fG"; action = "<cmd>lua Snacks.picker.git_files()<cr>"; options.desc = "Find git files"; }
    { mode = "n"; key = "<leader>fr"; action = "<cmd>lua Snacks.picker.recent()<cr>"; options.desc = "Recent files"; }
    { mode = "n"; key = "<leader>fb"; action = "<cmd>lua Snacks.picker.buffers()<cr>"; options.desc = "Buffers"; }
    { mode = "n"; key = "<leader>fh"; action = "<cmd>lua Snacks.picker.help()<cr>"; options.desc = "Help pages"; }
    { mode = "n"; key = "<leader>sg"; action = "<cmd>lua Snacks.picker.grep()<cr>"; options.desc = "Grep"; }
    { mode = "n"; key = "<leader>sw"; action = "<cmd>lua Snacks.picker.grep_word()<cr>"; options.desc = "Word"; }
    { mode = "n"; key = "<leader>sh"; action = "<cmd>lua Snacks.picker.help()<cr>"; options.desc = "Help pages"; }
    { mode = "n"; key = "<leader>sk"; action = "<cmd>lua Snacks.picker.keymaps()<cr>"; options.desc = "Keymaps"; }
    { mode = "n"; key = "<leader>ss"; action = "<cmd>lua Snacks.picker.lsp_symbols()<cr>"; options.desc = "LSP symbols"; }
    { mode = "n"; key = "<leader>sS"; action = "<cmd>lua Snacks.picker.lsp_workspace_symbols()<cr>"; options.desc = "Workspace symbols"; }
    { mode = "n"; key = "<leader>un"; action = "<cmd>lua Snacks.notifier.hide()<cr>"; options.desc = "Dismiss notifications"; }
    { mode = "n"; key = "<leader>z"; action = "<cmd>lua Snacks.zen()<cr>"; options.desc = "Zen mode"; }
    { mode = "n"; key = "<leader>fF"; action = "<cmd>Telescope find_files<cr>"; options.desc = "Find files (Telescope)"; }
    { mode = "n"; key = "<leader>sG"; action = "<cmd>Telescope live_grep<cr>"; options.desc = "Grep (Telescope)"; }
    { mode = "n"; key = "<leader>bp"; action = "<cmd>BufferLineTogglePin<cr>"; options.desc = "Toggle pin"; }
    { mode = "n"; key = "<leader>bP"; action = "<cmd>BufferLineGroupClose ungrouped<cr>"; options.desc = "Delete non-pinned buffers"; }
    { mode = "n"; key = "<leader>br"; action = "<cmd>BufferLineCloseRight<cr>"; options.desc = "Delete buffers to the right"; }
    { mode = "n"; key = "<leader>bl"; action = "<cmd>BufferLineCloseLeft<cr>"; options.desc = "Delete buffers to the left"; }
    { mode = "n"; key = "<leader>bo"; action = "<cmd>BufferLineCloseOthers<cr>"; options.desc = "Delete other buffers"; }
  ];
}
