# ---
# Module: Hopper Bot Containers
# Description: Declarative OCI containers for NapCatQQ and AstrBot
# Scope: Host
# ---

{ ... }: {
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      napcat = {
        image = "mlikiowa/napcat-docker:latest";
        volumes = [
          "/var/lib/napcat/config:/app/napcat/config"
        ];
        environment = {
          NAPCAT_GID = "0";
          NAPCAT_UID = "0";
        };
        extraOptions = [
          "--network=host"
        ];
      };

      astrbot = {
        image = "soulter/astrbot:latest";
        volumes = [
          "/var/lib/astrbot/data:/AstrBot/data"
        ];
        extraOptions = [
          "--network=host"
        ];
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/napcat/config 0755 root root -"
    "d /var/lib/astrbot/data 0755 root root -"
  ];
}
