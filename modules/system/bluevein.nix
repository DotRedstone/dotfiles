# ---
# Module: BlueVein
# Description: Dual-system Bluetooth key synchronization (Windows ↔ NixOS)
# ---

{ config, lib, pkgs, inputs, ... }:

let
  bluevein-pkg = pkgs.rustPlatform.buildRustPackage {
    pname = "bluevein";
    version = "source";
    src = inputs.bluevein;
    cargoLock = {
      lockFile = "${inputs.bluevein}/Cargo.lock";
    };

    nativeBuildInputs = with pkgs; [ 
      pkg-config 
    ];

    buildInputs = with pkgs; [ 
      dbus 
    ];
  };
in
{
  systemd.services.bluevein = {
    description = "BlueVein - Dual System Bluetooth Key Sync";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${bluevein-pkg}/bin/bluevein";
      Restart = "always";
      RestartSec = 3;
      
      User = "root";
      Group = "root";
      
      WorkingDirectory = "/var/lib/bluevein";
      StateDirectory = "bluevein";
      StateDirectoryMode = "0700";
      
      ProtectSystem = false;
      PrivateTmp = true;
    };

    environment = {
      BLUEVEIN_ADAPTER_MAC = "E4:C7:67:8B:AB:4F";
      BLUEVEIN_INTERVAL = "30";
    };
  };
}
