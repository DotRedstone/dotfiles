# ---
# Module: NixVim - Keymaps
# Description: Global editor keybindings and leader mappings
# Scope: Home Manager
# ---

{ ... }: {
  programs.nixvim.keymaps = [
    {
      mode = "i";
      key = "jk";
      action = "<Esc>";
      options.desc = "Exit insert mode";
    }

    # Mac-style / Super shortcuts. The terminal must pass Super keys through.
    {
      mode = [ "n" "v" ];
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
      mode = [ "n" "v" ];
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
      mode = [ "n" "v" "i" ];
      key = "<D-s>";
      action = "<cmd>w<cr>";
      options.desc = "Save file";
    }
    {
      mode = [ "n" "v" ];
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
      mode = [ "i" "n" ];
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
  ];
}
