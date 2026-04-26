# ---
# Module: Nixvim Keymaps
# Description: Global keybindings including Mac-style Super shortcuts
# ---

{ ... }: {
  programs.nixvim.keymaps = [
    # [Basic]
    {
      mode = "i";
      key = "jk";
      action = "<Esc>";
      options.desc = "Exit insert mode";
    }

    # [Mac-style / Super Shortcuts]
    # Note: These require the terminal to pass Super keys to Neovim
    {
      mode = [ "n" "v" "i" ];
      key = "<D-c>"; # D- is Cmd/Super in many terminal configs
      action = "\"+y";
      options.desc = "Copy to system clipboard";
    }
    {
      mode = [ "n" "v" "i" ];
      key = "<D-v>";
      action = "\"+p";
      options.desc = "Paste from system clipboard";
    }
    {
      mode = "n";
      key = "<D-s>";
      action = "<cmd>w<cr>";
      options.desc = "Save file";
    }
    {
      mode = [ "n" "v" "i" ];
      key = "<D-a>";
      action = "ggVG";
      options.desc = "Select all";
    }

    # [Window Management]
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
    }
  ];
}
