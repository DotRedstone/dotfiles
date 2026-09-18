# ---
# Module: Hardware - Audio
# Description: PipeWire audio server with ALSA and PulseAudio compatibility
# Scope: System
# ---

{ ... }: {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig."60-bluetooth-profile-stability" = {
      "wireplumber.settings" = {
        # MOONDROP EDGE 2 repeatedly loses its transport while WirePlumber
        # switches between AAC playback and HFP microphone mode.
        "bluetooth.autoswitch-to-headset-profile" = false;
        "bluetooth.use-persistent-storage" = false;
        "bluetooth.profile-preference" = "quality";
      };
    };
  };
}
