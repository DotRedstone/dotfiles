# ---
# Module: Zen Browser - Theme
# Description: Web terminal monospace font harmonization
# Scope: Home Manager
# ---

{ ... }: {
  programs.zen-browser.profiles.dot = {
    userChrome = ''
      /* ==========================================================================
         Zen Browser - Noctalia Dynamic Theme Integration
         ========================================================================== */
      @import url("/home/dot/.cache/noctalia/zen-browser/zen-userChrome.css");

      /* ==========================================================================
         Sidebar & Navigation Contrast Enhancements
         ========================================================================== */

      /* 0. 全局强制深色模式变量与消灭任何白色底色（彻底解决书签侧边栏、活动标签白色问题） */
      :root,
      #main-window,
      zen-workspace,
      .zen-workspace-tabs-section,
      #tabbrowser-tabs,
      #TabsToolbar,
      #vertical-tabs {
        color-scheme: dark !important;
        --sidebar-background-color: var(--base) !important;
        --sidebar-text-color: var(--text) !important;
        --sidebar-border-color: var(--outline) !important;
        --tab-background-color-selected: var(--hl_med) !important;
        --tab-box-shadow-selected: none !important;
        --zen-essential-tab-selected-bg: var(--hl_med) !important;
        --zen-essential-tab-selected-bg-hover: var(--hl_high) !important;
        --zen-selected-bg: var(--hl_med) !important;
        --zen-toolbar-element-bg: var(--surface) !important;
      }

      /* 书签、历史侧边栏外框全量深色化 */
      #sidebar-box,
      #sidebar-box #sidebar,
      #sidebar-header,
      #sidebar-search-container,
      .sidebar-panel,
      .sidebar-placesTree {
        background-color: var(--base) !important;
        background: var(--base) !important;
        color: var(--text) !important;
        color-scheme: dark !important;
      }

      #sidebar-header {
        background-color: var(--base) !important;
        border-bottom: 1px solid var(--outline) !important;
      }
      #sidebar-header #sidebar-title,
      #sidebar-header .sidebar-header-button {
        color: var(--primary) !important;
        fill: var(--primary) !important;
      }

      #sidebar-search-container,
      #sidebar-search-container input,
      #search-box {
        background-color: var(--surface) !important;
        color: var(--primary) !important;
        border: 1px solid var(--outline) !important;
        border-radius: 6px !important;
      }

      /* 1. 侧边栏容器变量：全量统一为与刷新/下载一致的亮青强调色 (Primary Cyan) */
      #navigator-toolbox,
      #zen-tabbox-wrapper,
      #TabsToolbar,
      #vertical-tabs {
        color-scheme: dark !important;
        --toolbarbutton-icon-fill: var(--primary) !important;
        --toolbar-field-color: var(--primary) !important;
        --toolbar-field-focus-color: var(--primary) !important;
        --toolbar-color: var(--primary) !important;
        --toolbox-textcolor: var(--primary) !important;
        --toolbox-textcolor-inactive: var(--primary) !important;
        --sidebar-text-color: var(--primary) !important;
        --lwt-text-color: var(--primary) !important;
        --lwt-sidebar-text-color: var(--primary) !important;
        --tab-selected-textcolor: var(--primary) !important;
      }

      /* 2. 顶部导航与底部操作栏按钮（...、侧边栏折叠、刷新、后退、前进、新建工作区+、下载等） */
      #zen-sidebar-top-buttons toolbarbutton,
      #zen-sidebar-foot-buttons toolbarbutton,
      #nav-bar toolbarbutton {
        color: var(--primary) !important;
      }

      #zen-sidebar-top-buttons toolbarbutton:not([disabled]) .toolbarbutton-icon,
      #zen-sidebar-foot-buttons toolbarbutton:not([disabled]) .toolbarbutton-icon,
      #nav-bar toolbarbutton:not([disabled]) .toolbarbutton-icon,
      #zen-sidebar-top-buttons toolbarbutton:not([disabled]) > image,
      #zen-sidebar-foot-buttons toolbarbutton:not([disabled]) > image {
        fill: var(--primary) !important;
        color: var(--primary) !important;
        opacity: 1 !important;
      }

      /* 3. 搜索/地址栏边框、文字、占位符与图标 */
      #urlbar-background,
      .urlbar-background {
        border: 1px solid color-mix(in srgb, var(--primary) 50%, var(--outline)) !important;
        background-color: var(--surface) !important;
      }
      #urlbar-input,
      .urlbar-input {
        color: var(--primary) !important;
      }
      #urlbar-input::placeholder,
      .urlbar-input::placeholder {
        color: var(--primary) !important;
        opacity: 0.8 !important;
      }
      #urlbar-search-button,
      .urlbar-icon,
      #identity-icon {
        fill: var(--primary) !important;
        color: var(--primary) !important;
      }

      /* 4. 工作区区域（Space 标题、图标、右侧更多按钮 ...） */
      .zen-current-workspace-indicator-name,
      #zen-current-workspace-indicator .zen-current-workspace-indicator-name,
      #zen-workspaces-button {
        color: var(--primary) !important;
        font-weight: 600 !important;
      }
      .zen-current-workspace-indicator-icon,
      #zen-current-workspace-indicator .zen-current-workspace-indicator-icon,
      #zen-workspaces-button .toolbarbutton-icon,
      #zen-workspaces-button * {
        fill: var(--primary) !important;
        color: var(--primary) !important;
      }

      /* 5. 侧边栏标签页文字与新建标签页文字统一为亮青强调色 */
      tabbrowser-tabs tab .tab-text,
      tab .tab-text,
      .tabbrowser-tab .tab-text,
      #tabs-newtab-button .toolbarbutton-text,
      #vertical-tabs-newtab-button .toolbarbutton-text,
      #newtab-button-container toolbarbutton .toolbarbutton-text {
        color: var(--primary) !important;
      }

      #tabs-newtab-button .toolbarbutton-icon,
      #vertical-tabs-newtab-button .toolbarbutton-icon,
      #newtab-button-container toolbarbutton .toolbarbutton-icon,
      .tabbrowser-tab .tab-icon-image {
        fill: var(--primary) !important;
      }

      /* 标签页关闭按钮 */
      .tab-close-button {
        fill: var(--primary) !important;
        color: var(--primary) !important;
        opacity: 0.7 !important;
      }
      .tab-close-button:hover {
        opacity: 1 !important;
      }

      /* 6. 新建标签页按钮背景与各状态（彻底消灭白底，与普通选中标签页保持一致） */
      #tabs-newtab-button,
      #vertical-tabs-newtab-button,
      #newtab-button-container toolbarbutton,
      #tabbrowser-tabs toolbarbutton#tabs-newtab-button,
      toolbarbutton[command="cmd_newNavigatorTab"],
      toolbarbutton[data-l10n-id="tabs-toolbar-new-tab"] {
        background-image: none !important;
        color: var(--primary) !important;
        border-radius: var(--border-radius-medium, 8px) !important;
        border: 1px solid transparent !important;
        box-shadow: none !important;
      }

      #tabs-newtab-button *,
      #vertical-tabs-newtab-button *,
      toolbarbutton[command="cmd_newNavigatorTab"] * {
        background: transparent !important;
        background-color: transparent !important;
      }

      #tabs-newtab-button::before,
      #tabs-newtab-button::after,
      #vertical-tabs-newtab-button::before,
      #vertical-tabs-newtab-button::after,
      toolbarbutton[command="cmd_newNavigatorTab"]::before,
      toolbarbutton[command="cmd_newNavigatorTab"]::after {
        background-image: none !important;
        box-shadow: none !important;
      }

      #tabs-newtab-button:hover:not([in-urlbar]):not([selected]),
      #vertical-tabs-newtab-button:hover:not([in-urlbar]):not([selected]),
      #newtab-button-container toolbarbutton:hover:not([in-urlbar]):not([selected]),
      toolbarbutton[command="cmd_newNavigatorTab"]:hover:not([in-urlbar]):not([selected]) {
        background-image: none !important;
        background: var(--hl_low) !important;
        background-color: var(--hl_low) !important;
        color: var(--primary) !important;
        border: 1px solid transparent !important;
        box-shadow: none !important;
      }

      #tabs-newtab-button:is(:active, :focus, :focus-visible, [open], [checked], [selected], [in-urlbar]),
      #tabs-newtab-button[in-urlbar],
      #tabs-newtab-button[in-urlbar="true"],
      #vertical-tabs-newtab-button:is(:active, :focus, :focus-visible, [open], [checked], [selected], [in-urlbar]),
      #vertical-tabs-newtab-button[in-urlbar],
      #vertical-tabs-newtab-button[in-urlbar="true"],
      #newtab-button-container toolbarbutton:is(:active, :focus, :focus-visible, [open], [checked], [selected], [in-urlbar]),
      toolbarbutton[command="cmd_newNavigatorTab"]:is(:active, :focus, :focus-visible, [open], [checked], [selected], [in-urlbar]),
      toolbarbutton[command="cmd_newNavigatorTab"][in-urlbar],
      #tabbrowser-tabs toolbarbutton#tabs-newtab-button:is(:active, :focus, :focus-visible, [open], [checked], [selected], [in-urlbar]),
      #tabbrowser-tabs toolbarbutton#tabs-newtab-button[in-urlbar] {
        background-image: none !important;
        background: var(--hl_med) !important;
        background-color: var(--hl_med) !important;
        color: var(--primary) !important;
        border: none !important;
        box-shadow: none !important;
        outline: none !important;
      }

      #tabs-newtab-button:is([in-urlbar], [selected]):hover,
      #vertical-tabs-newtab-button:is([in-urlbar], [selected]):hover,
      toolbarbutton[command="cmd_newNavigatorTab"]:is([in-urlbar], [selected]):hover {
        background-image: none !important;
        background: var(--hl_med) !important;
        background-color: var(--hl_med) !important;
        border: none !important;
        box-shadow: none !important;
      }

      /* 7. 选中标签页高对比度深色底色与清晰边框（彻底移除 Zen 原生白色渐变 background-image） */
      tabbrowser-tabs tab[selected] .tab-background,
      tabbrowser-tabs tab[selected],
      tab[selected] .tab-background,
      tab[selected],
      tab[visuallyselected] .tab-background,
      tab[visuallyselected],
      .tabbrowser-tab[selected="true"] .tab-background,
      .tabbrowser-tab[visuallyselected="true"] .tab-background,
      .tabbrowser-tab[selected] .tab-background,
      .tabbrowser-tab[multiselected] .tab-background,
      .tabbrowser-tab[zen-essential="true"][selected] .tab-background,
      .tabbrowser-tab[zen-essential="true"][visuallyselected] .tab-background {
        background-image: none !important;
        background: var(--hl_med) !important;
        background-color: var(--hl_med) !important;
        border: none !important;
        border-radius: 8px !important;
        box-shadow: none !important;
      }

      tabbrowser-tabs tab[selected] .tab-text,
      tab[selected] .tab-text,
      .tabbrowser-tab[selected="true"] .tab-text,
      .tabbrowser-tab[visuallyselected="true"] .tab-text,
      .tabbrowser-tab[selected] .tab-text,
      #tabs-newtab-button:is(:active, :focus, [selected], [in-urlbar]) .toolbarbutton-text,
      #vertical-tabs-newtab-button:is(:active, :focus, [selected], [in-urlbar]) .toolbarbutton-text {
        color: var(--primary) !important;
        font-weight: 600 !important;
      }

      tabbrowser-tabs tab:not([selected]):hover .tab-background,
      tab:not([selected]):hover .tab-background,
      .tabbrowser-tab:not([selected="true"]):hover .tab-background {
        background-image: none !important;
        background: var(--hl_low) !important;
        background-color: var(--hl_low) !important;
        border-radius: 8px !important;
        box-shadow: none !important;
      }

      /* 8. 地址栏激活与原地输入状态对比度 */
      #urlbar[focused="true"] #urlbar-background,
      #urlbar[breakout-extend="true"] #urlbar-background,
      #urlbar:is([focused], [open]) .urlbar-background {
        background-color: var(--surface) !important;
        border: 1px solid var(--primary) !important;
      }
    '';

    userContent = ''
      /* ==========================================================================
         Zen Browser - Noctalia Dynamic Content Integration
         ========================================================================== */
      @import url("/home/dot/.cache/noctalia/zen-browser/zen-userContent.css");

      /* ==========================================================================
         Web Terminal & Monospace Typography Harmonization
         ========================================================================== */

      /* Ensure web terminals (JupyterLab xterm.js, etc.) use clean monospace with 0 letter-spacing */
      .xterm,
      .xterm .xterm-screen,
      .xterm .xterm-rows,
      .xterm-screen canvas,
      .jp-Terminal-body,
      .jp-Terminal {
        font-family: "Maple Mono NF", "Sarasa Mono SC", monospace !important;
        letter-spacing: 0px !important;
      }

      /* ==========================================================================
         Bookmarks & History Sidebar Internal Document Dark Theming
         ========================================================================== */
      @-moz-document url-prefix("chrome://browser/content/places/") {
        :root,
        body,
        page,
        tree,
        #placesViews,
        #placesList,
        #bookmarks-view,
        #historyTree {
          background-color: #0f1416 !important;
          background: #0f1416 !important;
          color: #dee3e5 !important;
          color-scheme: dark !important;
        }
        treechildren {
          background-color: #0f1416 !important;
          color: #dee3e5 !important;
        }
        treechildren::-moz-tree-cell-text {
          color: #dee3e5 !important;
        }
        treechildren::-moz-tree-cell-text(selected) {
          color: #84d2e5 !important;
        }
        treechildren::-moz-tree-row(selected) {
          background-color: #303637 !important;
        }
        treechildren::-moz-tree-row(hover) {
          background-color: #252b2d !important;
        }
        treechildren::-moz-tree-image {
          fill: #84d2e5 !important;
        }
        #search-box {
          background-color: #171d1e !important;
          color: #84d2e5 !important;
          border: 1px solid #3f484b !important;
        }
      }
    '';
  };
}
