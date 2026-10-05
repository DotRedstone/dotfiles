# ---
# Module: Dolphin Theme Sync
# Description: Generates ~/.config/kdeglobals dynamically matching Noctalia palette
# Scope: Home Manager
# ---

{ pkgs, ... }:

let
  kdeglobalsInjector = pkgs.writeShellScriptBin "kdeglobals-injector" ''
    set -eu
    ${pkgs.python3}/bin/python3 - <<'EOF'
import json
import os

def hex_to_rgb(hex_str, alpha=None):
    hex_str = hex_str.lstrip('#')
    if len(hex_str) == 6:
        r, g, b = int(hex_str[0:2], 16), int(hex_str[2:4], 16), int(hex_str[4:6], 16)
        if alpha is not None:
            return f"{r},{g},{b},{alpha}"
        return f"{r},{g},{b}"
    return f"128,128,128,{alpha}" if alpha is not None else "128,128,128"

colors_file = os.path.expanduser("~/.cache/dolphin-noctalia-theme/colors.json")
wal_file = os.path.expanduser("~/.cache/wal/colors.json")

data = None
if os.path.exists(colors_file):
    try:
        with open(colors_file, "r") as f:
            data = json.load(f)
    except Exception:
        pass

if not data and os.path.exists(wal_file):
    try:
        with open(wal_file, "r") as f:
            wal_data = json.load(f)
            data = {
                "mode": "dark",
                "surface": wal_data["special"]["background"],
                "on_surface": wal_data["special"]["foreground"],
                "surface_variant": wal_data["colors"]["color10"],
                "on_surface_variant": wal_data["colors"]["color15"],
                "primary": wal_data["colors"]["color1"],
                "on_primary": "#141318",
                "primary_container": wal_data["colors"]["color9"],
                "outline": wal_data["colors"]["color8"],
            }
    except Exception:
        pass

if not data:
    exit(0)

is_dark = data.get("mode", "dark") != "light"
icon_theme = "Papirus-Dark" if is_dark else "Papirus-Light"

bg_window = hex_to_rgb(data.get("surface", "#141318" if is_dark else "#fdfbff"), alpha=120)
variant_window = hex_to_rgb(data.get("surface_variant", "#484459" if is_dark else "#e5e1ec"), alpha=120)

bg_view = hex_to_rgb(data.get("surface", "#141318" if is_dark else "#fdfbff"), alpha=180)
variant_view = hex_to_rgb(data.get("surface_variant", "#484459" if is_dark else "#e5e1ec"), alpha=180)

bg_header = hex_to_rgb(data.get("surface", "#141318" if is_dark else "#fdfbff"), alpha=120)
variant_header = hex_to_rgb(data.get("surface_variant", "#484459" if is_dark else "#e5e1ec"), alpha=120)

fg = hex_to_rgb(data.get("on_surface", "#e5e1e9" if is_dark else "#1a1b1f"))
primary = hex_to_rgb(data.get("primary", "#c8bfff" if is_dark else "#5c53a6"))
on_primary = hex_to_rgb(data.get("on_primary", "#141318" if is_dark else "#ffffff"))
card = hex_to_rgb(data.get("primary_container", "#473f77" if is_dark else "#e5deff"), alpha=150)
variant = hex_to_rgb(data.get("surface_variant", "#484459" if is_dark else "#e5e1ec"), alpha=150)
variant_fg = hex_to_rgb(data.get("on_surface_variant", "#c9c5d0" if is_dark else "#48454e"))
outline = hex_to_rgb(data.get("outline", "#938f99" if is_dark else "#787680"))

content = f"""[General]
ColorScheme=noctalia
Name=noctalia
TerminalApplication=wezterm
TerminalService=org.wezfurlong.wezterm.desktop
font=Maple Mono NF,11,-1,5,50,0,0,0,0,0
fixed=Maple Mono NF,11,-1,5,50,0,0,0,0,0
smallestReadableFont=Maple Mono NF,9,-1,5,50,0,0,0,0,0
toolBarFont=Maple Mono NF,10,-1,5,50,0,0,0,0,0
menuFont=Maple Mono NF,10,-1,5,50,0,0,0,0,0
AccentColor={primary}
LastUsedCustomAccentColor={primary}
accentColorFromWallpaper=false

[KDE]
colorScheme=noctalia
widgetStyle=Breeze
ShowIconsInMenuItems=true
ShowIconsOnPushButtons=true

[Icons]
Theme={icon_theme}

[Colors:Window]
BackgroundNormal={bg_window}
BackgroundAlternate={variant_window}
ForegroundNormal={fg}
ForegroundInactive={outline}
ForegroundActive={primary}
ForegroundLink={primary}
ForegroundVisited={variant_fg}
ForegroundNegative=255,180,171
ForegroundNeutral={primary}
ForegroundPositive=180,255,180
DecorationFocus={primary}
DecorationHover={primary}

[Colors:View]
BackgroundNormal={bg_view}
BackgroundAlternate={variant_view}
ForegroundNormal={fg}
ForegroundInactive={outline}
ForegroundActive={primary}
ForegroundLink={primary}
ForegroundVisited={variant_fg}
ForegroundNegative=255,180,171
ForegroundNeutral={primary}
ForegroundPositive=180,255,180
DecorationFocus={primary}
DecorationHover={primary}

[Colors:Button]
BackgroundNormal={variant}
BackgroundAlternate={card}
ForegroundNormal={fg}
ForegroundInactive={outline}
ForegroundActive={primary}
ForegroundLink={primary}
ForegroundVisited={variant_fg}
ForegroundNegative=255,180,171
ForegroundNeutral={primary}
ForegroundPositive=180,255,180
DecorationFocus={primary}
DecorationHover={primary}

[Colors:Selection]
BackgroundNormal={primary}
BackgroundAlternate={primary}
ForegroundNormal={on_primary}
ForegroundInactive={on_primary}
ForegroundActive={on_primary}
ForegroundLink={on_primary}
DecorationFocus={primary}
DecorationHover={primary}

[Colors:Header]
BackgroundNormal={bg_header}
BackgroundAlternate={variant_header}
ForegroundNormal={fg}
ForegroundInactive={outline}
ForegroundActive={primary}
DecorationFocus={primary}
DecorationHover={primary}

[Colors:Header][Inactive]
BackgroundNormal={bg_header}
BackgroundAlternate={variant_header}
ForegroundNormal={outline}
ForegroundInactive={outline}
DecorationFocus={primary}
DecorationHover={primary}

[Colors:Tooltip]
BackgroundNormal={variant}
BackgroundAlternate={bg_window}
ForegroundNormal={fg}
ForegroundInactive={outline}
DecorationFocus={primary}
DecorationHover={primary}

[WM]
activeBackground={bg_window}
activeForeground={fg}
inactiveBackground={bg_window}
inactiveForeground={outline}
"""

scheme_dir = os.path.expanduser("~/.local/share/color-schemes")
os.makedirs(scheme_dir, exist_ok=True)
with open(os.path.join(scheme_dir, "noctalia.colors"), "w", encoding="utf-8") as f:
    f.write(content)

kde_globals_path = os.path.expanduser("~/.config/kdeglobals")
with open(kde_globals_path, "w", encoding="utf-8") as f:
    f.write(content)

dolphin_dir = os.path.expanduser("~/.config/dolphin")
os.makedirs(dolphin_dir, exist_ok=True)
qss_content = f"""/* Dolphin Noctalia Stylesheet */
KFilePlacesView, QListView#placesView, DolphinPlacesView {{
    background-color: transparent;
    border: none;
    outline: none;
    selection-background-color: transparent;
    selection-color: #ffffff;
}}

KFilePlacesView::item, QListView#placesView::item {{
    border-radius: 6px;
    padding: 5px 8px;
    margin: 2px 8px;
    color: #e5e1e9;
    border: none;
}}

KFilePlacesView::item:hover:!selected, QListView#placesView::item:hover:!selected {{
    background-color: rgba(255, 255, 255, 0.07);
    color: #ffffff;
}}

KFilePlacesView::item:selected, QListView#placesView::item:selected {{
    background-color: rgba({primary}, 0.16);
    color: #ffffff;
    font-weight: 500;
}}

DolphinViewContainer > QWidget {{
    border: none;
}}

QScrollBar:vertical {{
    border: none;
    background: transparent;
    width: 6px;
    margin: 0;
}}

QScrollBar::handle:vertical {{
    background: rgba(255, 255, 255, 0.2);
    min-height: 20px;
    border-radius: 3px;
}}

QScrollBar::handle:vertical:hover {{
    background: rgba(255, 255, 255, 0.4);
}}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
    background: none;
    border: none;
}}
"""
with open(os.path.join(dolphin_dir, "dolphin.qss"), "w", encoding="utf-8") as f:
    f.write(qss_content)

print("Updated ~/.local/share/color-schemes/noctalia.colors, ~/.config/kdeglobals and ~/.config/dolphin/dolphin.qss")
EOF
  '';
in {
  home.packages = [ kdeglobalsInjector ];
}
