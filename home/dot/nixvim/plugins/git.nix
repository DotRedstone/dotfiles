# ---
# Module: NixVim - Git Plugins
# Description: Git integration and diff visualization tools
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.plugins = {
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
  };

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>gg"; action = "<cmd>lua Snacks.lazygit()<cr>"; options.desc = "Lazygit"; }
    { mode = "n"; key = "<leader>gb"; action = "<cmd>lua Snacks.picker.git_branches()<cr>"; options.desc = "Git branches"; }
    { mode = "n"; key = "<leader>gc"; action = "<cmd>lua Snacks.picker.git_log()<cr>"; options.desc = "Git log"; }
    { mode = "n"; key = "<leader>gs"; action = "<cmd>lua Snacks.picker.git_status()<cr>"; options.desc = "Git status"; }
    { mode = "n"; key = "<leader>ghb"; action = "<cmd>Gitsigns blame_line<cr>"; options.desc = "Blame line"; }
    { mode = "n"; key = "<leader>ghR"; action = "<cmd>Gitsigns reset_buffer<cr>"; options.desc = "Reset buffer"; }
    { mode = "n"; key = "<leader>ghr"; action = "<cmd>Gitsigns reset_hunk<cr>"; options.desc = "Reset hunk"; }
    { mode = "n"; key = "<leader>ghs"; action = "<cmd>Gitsigns stage_hunk<cr>"; options.desc = "Stage hunk"; }
    { mode = "n"; key = "<leader>ghu"; action = "<cmd>Gitsigns undo_stage_hunk<cr>"; options.desc = "Undo stage hunk"; }
  ];
}
