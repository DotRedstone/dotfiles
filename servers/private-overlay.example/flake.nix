# ---
# Module: Private Server Overlay Example
# Description: Wrap the public server Flake with deployment-only Nix values
# Scope: Flake
# ---

{
  description = "Synthetic example for a private server deployment overlay";

  inputs.public.url = "github:DotRedstone/dotfiles?dir=servers";

  outputs = { public, ... }: {
    nixosConfigurations = {
      conduit = public.nixosConfigurations.conduit.extendModules {
        modules = [ ./conduit.nix ];
      };
      hopper = public.nixosConfigurations.hopper.extendModules {
        modules = [ ./hopper.nix ];
      };
      target = public.nixosConfigurations.target.extendModules {
        modules = [ ./target.nix ];
      };
    };
  };
}
