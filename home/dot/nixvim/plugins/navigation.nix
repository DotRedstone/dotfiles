# ---
# Module: NixVim - Navigation Plugins
# Description: Navigation and key discovery tools (Flash, Which-key)
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.plugins = {
    flash = {
      enable = true;
      settings = {
        labels = "asdfghjklqwertyuiopzxcvbnm";
        modes.search.enabled = true;
      };
    };

    which-key = {
      enable = true;
      settings = {
        preset = "modern";
        delay = 250;
        spec = [
          { __unkeyed-1 = "<leader>b"; group = "buffer"; }
          { __unkeyed-1 = "<leader>c"; group = "code"; }
          { __unkeyed-1 = "<leader>f"; group = "file/find"; }
          { __unkeyed-1 = "<leader>g"; group = "git"; }
          { __unkeyed-1 = "<leader>q"; group = "quit/session"; }
          { __unkeyed-1 = "<leader>s"; group = "search/symbols"; }
          { __unkeyed-1 = "<leader>u"; group = "ui"; }
          { __unkeyed-1 = "<leader>w"; group = "windows"; }
          { __unkeyed-1 = "<leader>x"; group = "diagnostics/quickfix"; }
        ];
      };
    };
  };

  programs.nixvim.keymaps = [
    { mode = [ "n" "x" "o" ]; key = "s"; action = "<cmd>lua require('flash').jump()<cr>"; options.desc = "Flash"; }
    { mode = [ "n" "o" ]; key = "S"; action = "<cmd>lua require('flash').treesitter()<cr>"; options.desc = "Flash Treesitter"; }
    { mode = "o"; key = "r"; action = "<cmd>lua require('flash').remote()<cr>"; options.desc = "Remote Flash"; }
    { mode = [ "o" "x" ]; key = "R"; action = "<cmd>lua require('flash').treesitter_search()<cr>"; options.desc = "Treesitter Search"; }
    { mode = "c"; key = "<C-s>"; action = "<cmd>lua require('flash').toggle()<cr>"; options.desc = "Toggle Flash Search"; }
  ];
}
