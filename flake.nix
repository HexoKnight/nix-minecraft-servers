{
  description = "nix-minecraft server config";

  inputs = {
    # only for locking nix-packwiz downstream
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";
    nix-packwiz = {
      url = "github:HexoKnight/nix-packwiz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nix-packwiz, ... }:
  {
    nixosModules = rec {
      servers = {
        imports = [ ./servers ];
        nixpkgs.overlays = [ nix-packwiz.overlays.default ];
      };
      default = servers;
    };
  };
}
