# ---
# Module: NixVim - Treesitter
# Description: Incremental parsing and syntax highlighting with Treesitter
# ---

{ ... }: {
  programs.nixvim.plugins = {
    treesitter = {
      enable = true;
      nixGrammars = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        ensure_installed = [
          "bash" "c" "cmake" "cpp" "css" "dockerfile" "gitcommit" "gitignore"
          "html" "java" "javascript" "json" "jsonc" "lua" "markdown"
          "markdown_inline" "nix" "python" "query" "regex" "rust" "sql"
          "toml" "tsx" "typescript" "vim" "vimdoc" "vue" "yaml"
        ];
      };
    };
    treesitter-textobjects.enable = true;
    ts-autotag.enable = true;
    ts-comments.enable = true;
    render-markdown.enable = true;
    markdown-preview.enable = true;
  };
}
