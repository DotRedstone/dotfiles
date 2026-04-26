# ---
# Module: Nixvim Options
# Description: Global Neovim settings and behavior
# ---

{ ... }: {
  programs.nixvim.opts = {
    # [UI]
    number = true;         # Show line numbers
    relativenumber = true; # Relative line numbers
    termguicolors = true;  # True color support
    cursorline = true;     # Highlight current line
    signcolumn = "yes";    # Always show sign column

    # [Search]
    ignorecase = true;     # Ignore case in search
    smartcase = true;      # Smart case search
    hlsearch = true;       # Highlight search results

    # [Indentation]
    tabstop = 2;           # Number of spaces a tab counts for
    shiftwidth = 2;        # Number of spaces for autoindent
    expandtab = true;      # Use spaces instead of tabs
    smartindent = true;    # Smart autoindenting

    # [Undo & Swap]
    undofile = true;       # Persistent undo
    swapfile = false;      # Disable swap files
    backup = false;        # Disable backup files

    # [Misc]
    scrolloff = 8;         # Minimum lines to keep above/below cursor
    updatetime = 250;      # Faster completion/diagnostics
    timeoutlen = 300;      # Faster key sequence completion
    clipboard = "unnamedplus"; # Use system clipboard
  };
}
