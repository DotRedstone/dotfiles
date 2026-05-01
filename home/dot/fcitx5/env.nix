# ---
# Module: Fcitx5 Environment
# Description: Global IM environment variables (GTK, QT, XMODIFIERS, etc.)
# ---

{ ... }: {
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };
}
