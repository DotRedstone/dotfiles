# ---
# Module: Users - DevGuest
# Description: Restricted guest user for remote collaboration
# Scope: System
# ---

{ pkgs, ... }: {
  users.users.devguest = {
    isNormalUser = true;
    shell = pkgs.bash;
    # No extraGroups like wheel. Just basic access.
    # No password authentication
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAhM6efdjfKJJ6gszflOL1ld2UrFyGWwpvgcJCQMVzu dot@warden"
    ];
  };
}
