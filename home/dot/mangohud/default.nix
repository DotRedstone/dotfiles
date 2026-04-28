# ---
# Module: MangoHud
# Description: Vulkan/OpenGL overlay for monitoring FPS and hardware state
# ---

{ pkgs, ... }: {
  programs.mangohud = {
    enable = true;
    enableSessionWide = false; # Disable global injection to avoid showing up in GPU-accelerated terminals
    
    settings = {
      # [Position & Layout]
      position = "top-left";
      round_corners = 10;
      background_alpha = 0.5;
      
      # [Monitoring Items]
      fps = true;
      cpu_stats = true;
      cpu_temp = true;
      gpu_stats = true;
      gpu_temp = true;
      ram = true;
      vram = true;
      
      # [Theme]
      text_color = "FFFFFF";
      gpu_color = "88B090"; # Subtle green
      cpu_color = "B08890"; # Subtle red
      
      font_size = 18;
      font_file = "${pkgs.maple-mono.NF}/share/fonts/truetype/MapleMono-NF-Regular.ttf";
    };
  };
}
