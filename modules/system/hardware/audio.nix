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
  };
}
