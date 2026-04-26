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
    
    # [Window Resizing]
    { mode = "n"; key = "<C-Up>"; action = "<cmd>resize +2<cr>"; options.desc = "Increase window height"; }
    { mode = "n"; key = "<C-Down>"; action = "<cmd>resize -2<cr>"; options.desc = "Decrease window height"; }
    { mode = "n"; key = "<C-Left>"; action = "<cmd>vertical resize -2<cr>"; options.desc = "Decrease window width"; }
    { mode = "n"; key = "<C-Right>"; action = "<cmd>vertical resize +2<cr>"; options.desc = "Increase window width"; }

    # [Buffer Navigation]
    { mode = "n"; key = "<S-h>"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
    { mode = "n"; key = "<S-l>"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
    { mode = "n"; key = "[b"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
    { mode = "n"; key = "]b"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }
    { mode = "n"; key = "<leader>bb"; action = "<cmd>e #<cr>"; options.desc = "Switch to Other Buffer"; }
    { mode = "n"; key = "<leader>bd"; action = "<cmd>bd<cr>"; options.desc = "Delete Buffer"; }

    # [File/System]
    { mode = "n"; key = "<leader>w"; action = "<cmd>w<cr>"; options.desc = "Save File"; }
    { mode = "n"; key = "<leader>q"; action = "<cmd>qa<cr>"; options.desc = "Quit All"; }
    { mode = "n"; key = "<leader>qq"; action = "<cmd>qa!<cr>"; options.desc = "Force Quit All"; }

    # [Window Splitting]
    { mode = "n"; key = "<leader>-"; action = "<C-W>s"; options.desc = "Split Window Below"; }
    { mode = "n"; key = "<leader>|"; action = "<C-W>v"; options.desc = "Split Window Right"; }

    # [Move Lines]
    { mode = "n"; key = "<A-j>"; action = "<cmd>m .+1<cr>=="; options.desc = "Move Down"; }
    { mode = "n"; key = "<A-k>"; action = "<cmd>m .-2<cr>=="; options.desc = "Move Up"; }
    { mode = "i"; key = "<A-j>"; action = "<esc><cmd>m .+1<cr>==gi"; options.desc = "Move Down"; }
    { mode = "i"; key = "<A-k>"; action = "<esc><cmd>m .-2<cr>==gi"; options.desc = "Move Up"; }
    { mode = "v"; key = "<A-j>"; action = ":m '>+1<cr>gv=gv"; options.desc = "Move Down"; }
    { mode = "v"; key = "<A-k>"; action = ":m '<-2<cr>gv=gv"; options.desc = "Move Up"; }

    # [Search & Navigation]
    { mode = [ "i" "n" ]; key = "<esc>"; action = "<cmd>noh<cr><esc>"; options.desc = "Escape and Clear hlsearch"; }
    { mode = "n"; key = "n"; action = "nzzzv"; options.desc = "Next Search Result"; }
    { mode = "n"; key = "N"; action = "Nzzzv"; options.desc = "Prev Search Result"; }

    # [Indentation]
    { mode = "v"; key = "<"; action = "<gv"; }
    { mode = "v"; key = ">"; action = ">gv"; }
  ];
}
