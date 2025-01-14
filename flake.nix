{
  description = "nix-minecraft server config";

  inputs = {};

  outputs = { self }:
  {
    overlays = {
      default = final: prev: {
        buildPackwizModpack = final.callPackage ./pkgs/buildPackwizModpack.nix {};
      };
    };

    nixosModules = rec {
      servers = {
        imports = [ ./servers ];
        nixpkgs.overlays = [ self.overlays.default ];
      };
      default = servers;
    };
  };
}
