# ---
# Module: Networking
# Description: NetworkManager and Polkit rules for proxy tools
# ---

{ pkgs, ... }: {
  # [NetworkManager]
  networking.networkmanager.enable = true;

  # [Privilege Escalation - FlClash]
  # Allow wheel group to run flclash TUN mode without password

  security.sudo.extraRules = [{
    users = [ "dot" ];
    commands = [{
      command = "${pkgs.flclash}/bin/flclash";
      options = [ "NOPASSWD" ];
    }];
  }];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.policykit.exec" &&
           action.lookup("program") == "${pkgs.flclash}/bin/flclash") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
