# ---
# Module: Nixvim Options
# Description: Global Neovim settings and behavior
# ---

{ ... }: {
  programs.nixvim.globals = {
    mapleader = " ";
    maplocalleader = " ";
  };

  programs.nixvim.opts = {
    # [UI]
    number = true;
    relativenumber = true;
    termguicolors = true;
    cursorline = true;
    signcolumn = "yes";
    laststatus = 3;        # Global statusline
    pumblend = 10;         # Popup blend
    pumheight = 10;        # Maximum number of entries in a popup
    scrolloff = 4;         # Lines of context
    sidescrolloff = 8;     # Columns of context
    conceallevel = 3;      # Hide * markup for bold and italic
    wrap = false;          # Disable line wrap

    # [Search]
    ignorecase = true;
    smartcase = true;
    hlsearch = true;
    inccommand = "nosplit"; # preview incremental substitute

    # [Indentation & Formatting]
    tabstop = 2;
    shiftwidth = 2;
    expandtab = true;
    smartindent = true;
    shiftround = true;     # Round indent
    formatoptions = "jcroqlnt";

    # [Behavior]
    autowrite = true;      # Enable auto write
    confirm = true;        # Confirm to save changes before exiting modified buffer
    splitbelow = true;     # Put new windows below current
    splitright = true;     # Put new windows right of current
    splitkeep = "screen";
    virtualedit = "block"; # Allow cursor to move where there is no text in visual block mode

    # [Undo, Swap & Session]
    undofile = true;
    swapfile = false;
    backup = false;
    sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds";

    # [Misc]
    updatetime = 200;      # Save swap file and trigger CursorHold
    timeoutlen = 300;      # Lower than default (1000) to quickly trigger which-key
    clipboard = "unnamedplus";
  };
}
