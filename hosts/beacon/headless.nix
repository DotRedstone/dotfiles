# ---
# Module: Beacon Headless Configuration
# Description: Power management, auto-restart, sleep prevention, and headless tuning
# Scope: Host
# ---

{ ... }:

{
  # [System Defaults]
  system.defaults = {
    # Disable guest account
    loginwindow.GuestEnabled = false;

    # Suppress crash dialogs that block background processes
    CustomUserPreferences = {
      "com.apple.CrashReporter" = {
        DialogType = "none";
      };
    };
  };

  # [Power Management]
  # Configures pmset to prevent sleep, auto-restart on AC loss, and enable WoL.
  system.activationScripts.postActivation.text = ''
    echo "[Headless] Configuring power management (pmset)..."
    # Never sleep system or disks
    /usr/bin/sudo /usr/bin/pmset -a sleep 0
    /usr/bin/sudo /usr/bin/pmset -a displaysleep 0
    /usr/bin/sudo /usr/bin/pmset -a disksleep 0
    # Enable Wake on LAN / Network Access
    /usr/bin/sudo /usr/bin/pmset -a womp 1
    # Auto-restart on power failure
    /usr/bin/sudo /usr/bin/pmset -a autorestart 1
    # Disable Power Nap
    /usr/bin/sudo /usr/bin/pmset -a powernap 0
  '';
}
