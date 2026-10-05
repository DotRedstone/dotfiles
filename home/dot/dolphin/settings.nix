# ---
# Module: Dolphin Settings
# Description: Modern view options, thumbnail settings, and places panel integration for Dolphin
# Scope: Home Manager
# ---

{ pkgs, lib, ... }: {
  # [Activation / Runtime defaults]
  home.activation.ensureDolphinDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 - <<'EOF'
import os
import configparser
import xml.etree.ElementTree as ET

# 1. dolphinrc configuration
dolphinrc_path = os.path.expanduser("~/.config/dolphinrc")
config = configparser.ConfigParser(interpolation=None)
config.optionxform = str
if os.path.exists(dolphinrc_path):
    config.read(dolphinrc_path, encoding="utf-8")

defaults = {
    "General": {
        "GlobalViewProps": "true",
        "ShowFullPath": "false",
        "ShowPreviews": "true",
        "ShowZoomSlider": "false",
        "ShowSpaceInfo": "true",
        "BrowseThroughArchives": "true",
        "AutoExpandFolders": "false",
        "OpenExternallyCalledFolderInNewTab": "true",
        "ShowStatusBar": "Disabled",
        "AlwaysShowTabBar": "false",
        "RememberOpenedTabs": "false",
        "Version": "202",
    },
    "IconsMode": {
        "IconSize": "64",
        "PreviewSize": "64",
        "MaximumTextLines": "2",
    },
    "CompactMode": {
        "IconSize": "22",
        "PreviewSize": "22",
    },
    "DetailsMode": {
        "IconSize": "22",
        "PreviewSize": "22",
        "SidePadding": "2",
    },
    "KFileDialog Settings": {
        "Places Icons Auto-resize": "false",
        "Places Icons Static Size": "22",
    },
    "MainWindow": {
        "MenuBar": "Disabled",
        "ToolBarsMovable": "Disabled",
        "ToolButtonStyle": "IconOnly",
    },
    "Interface": {
        "activate_item_on_single_click": "0",
    },
    "PreviewSettings": {
        "Plugins": "audiothumbnail,comicbookthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,krapathumbnail,svgthumbnail,videothumbnail,windowsexethumbnail,xcursorthumbnail,appimagethumbnail,epubthumbnail,msofficeextensionthumbnail,opendocumentthumbnail",
    }
}

for section, entries in defaults.items():
    if not config.has_section(section):
        config.add_section(section)
    for k, v in entries.items():
        for existing_k in list(config.options(section)):
            if existing_k.lower() == k.lower() and existing_k != k:
                config.remove_option(section, existing_k)
        config.set(section, k, v)

with open(dolphinrc_path, "w", encoding="utf-8") as f:
    config.write(f, space_around_delimiters=False)

# 2. Global directory view properties
global_dir = os.path.expanduser("~/.local/share/dolphin/view_properties/global")
os.makedirs(global_dir, exist_ok=True)
with open(os.path.join(global_dir, ".directory"), "w", encoding="utf-8") as f:
    f.write("[Dolphin]\nMode=0\nSortRole=text\nSortOrder=0\nVisibleRoles=\n")

# 3. Places panel bookmarks
places_path = os.path.expanduser("~/.local/share/user-places.xbel")
items = [
    ("file:///home/dot", "主文件夹", "user-home-symbolic"),
    ("file:///home/dot/Projects", "Projects", "folder-symbolic"),
    ("file:///home/dot/Downloads", "下载", "folder-download-symbolic"),
    ("file:///home/dot/Pictures", "图片", "folder-pictures-symbolic"),
    ("file:///home/dot/Videos", "视频", "folder-videos-symbolic"),
    ("file:///home/dot/Documents", "文档", "folder-documents-symbolic"),
    ("file:///home/dot/Music", "音乐", "folder-music-symbolic"),
    ("file:///home/dot/.dotfiles", "Dotfiles", "folder-saved-search-symbolic"),
    ("trash:/", "回收站", "user-trash-symbolic"),
]

import time
base_id = int(time.time())
bookmarks_xml = []
for idx, (url, title, icon) in enumerate(items):
    is_sys = "true" if "file:///home/dot" in url or "trash" in url else "false"
    bookmarks_xml.append(f""" <bookmark href="{url}" icon="{icon}">
  <title>{title}</title>
  <info>
   <metadata owner="http://freedesktop.org">
    <bookmark:icon name="{icon}"/>
   </metadata>
   <metadata owner="http://www.kde.org">
    <ID>{base_id}/{idx}</ID>
    <isSystemItem>{is_sys}</isSystemItem>
   </metadata>
  </info>
 </bookmark>""")

xbel_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<xbel>
 <info>
  <metadata owner="http://www.kde.org">
   <kde_places_version>4</kde_places_version>
   <GroupState-Places-IsHidden>false</GroupState-Places-IsHidden>
   <GroupState-Remote-IsHidden>true</GroupState-Remote-IsHidden>
   <GroupState-Devices-IsHidden>false</GroupState-Devices-IsHidden>
   <GroupState-RemovableDevices-IsHidden>false</GroupState-RemovableDevices-IsHidden>
   <GroupState-Tags-IsHidden>true</GroupState-Tags-IsHidden>
   <withBaloo>true</withBaloo>
   <GroupState-SearchFor-IsHidden>true</GroupState-SearchFor-IsHidden>
   <GroupState-RecentlySaved-IsHidden>true</GroupState-RecentlySaved-IsHidden>
  </metadata>
 </info>
{"".join(bookmarks_xml)}
</xbel>
"""
with open(places_path, "w", encoding="utf-8") as f:
    f.write(xbel_content)

# 4. Default Noctalia stylesheet for Dolphin
dolphin_dir = os.path.expanduser("~/.config/dolphin")
os.makedirs(dolphin_dir, exist_ok=True)
qss_path = os.path.join(dolphin_dir, "dolphin.qss")
if not os.path.exists(qss_path):
    with open(qss_path, "w", encoding="utf-8") as f:
        f.write("""/* Dolphin Noctalia Stylesheet */
KFilePlacesView, QListView#placesView, DolphinPlacesView {
    background-color: transparent;
    border: none;
    outline: none;
    selection-background-color: transparent;
    selection-color: #ffffff;
}

KFilePlacesView::item, QListView#placesView::item {
    border-radius: 6px;
    padding: 5px 8px;
    margin: 2px 8px;
    color: #e5e1e9;
    border: none;
}

KFilePlacesView::item:hover:!selected, QListView#placesView::item:hover:!selected {
    background-color: rgba(255, 255, 255, 0.07);
    color: #ffffff;
}

KFilePlacesView::item:selected, QListView#placesView::item:selected {
    background-color: rgba(200, 191, 255, 0.16);
    color: #ffffff;
    font-weight: 500;
}

DolphinViewContainer > QWidget {
    border: none;
}

QScrollBar:vertical {
    border: none;
    background: transparent;
    width: 6px;
    margin: 0;
}

QScrollBar::handle:vertical {
    background: rgba(255, 255, 255, 0.2);
    min-height: 20px;
    border-radius: 3px;
}

QScrollBar::handle:vertical:hover {
    background: rgba(255, 255, 255, 0.4);
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
    background: none;
    border: none;
}
""")

# 5. Modern toolbar layout matching Nautilus (kxmlgui5)
kxmlgui_dir = os.path.expanduser("~/.local/share/kxmlgui5/dolphin")
os.makedirs(kxmlgui_dir, exist_ok=True)
dolphinui_content = """<?xml version="1.0"?>
<!DOCTYPE gui SYSTEM "kpartgui.dtd">
<gui name="dolphin" version="49">
    <MenuBar>
        <Menu name="file">
            <Action name="new_menu" />
            <Action name="file_new" />
            <Action name="new_tab" />
            <Action name="file_close" />
            <Action name="undo_close_tab" />
            <Separator/>
            <Action name="add_to_places" />
            <Separator/>
            <Action name="renamefile" />
            <Action name="duplicate" />
            <Action name="movetotrash" />
            <Action name="deletefile" />
            <Action name="properties" />
        </Menu>
        <Menu name="edit">
            <Action name="edit_undo" />
            <Action name="edit_redo" />
            <Separator/>
            <Action name="edit_cut" />
            <Action name="edit_copy" />
            <Action name="edit_paste" />
            <Separator/>
            <Action name="edit_select_all" />
            <Action name="invert_selection" />
        </Menu>
        <Menu name="view">
            <Action name="view_mode" />
            <Action name="sort" />
            <Action name="show_preview" />
            <Action name="show_hidden_files" />
            <Separator/>
            <Action name="split_view" />
            <Action name="redisplay" />
            <Separator/>
            <Action name="panels" />
        </Menu>
        <Menu name="tools">
            <Action name="open_terminal" />
            <Action name="open_terminal_here" />
            <Action name="compare_files" />
        </Menu>
        <Menu name="settings">
            <Action name="options_configure_keybinding" />
            <Action name="options_configure_toolbars" />
            <Action name="options_configure" />
        </Menu>
    </MenuBar>
    <ToolBar noMerge="1" name="mainToolBar">
        <text context="@title:menu">Main Toolbar</text>
        <Action name="go_back" />
        <Action name="go_forward" />
        <Action name="url_navigators" />
        <Action name="toggle_search" />
        <Action name="view_mode" />
        <Action name="split_view" />
        <Action name="hamburger_menu" />
    </ToolBar>
    <ActionProperties scheme="Default">
        <Action priority="0" name="go_back"/>
        <Action priority="0" name="go_forward"/>
        <Action priority="0" name="toggle_search"/>
        <Action priority="0" name="view_mode"/>
        <Action priority="0" name="split_view"/>
        <Action priority="0" name="hamburger_menu"/>
    </ActionProperties>
</gui>
"""
with open(os.path.join(kxmlgui_dir, "dolphinui.rc"), "w", encoding="utf-8") as f:
    f.write(dolphinui_content)
EOF
    ${pkgs.xdg-utils}/bin/xdg-mime default org.kde.dolphin.desktop inode/directory 2>/dev/null || true
  '';
}
