{ lib, pkgs, ... }@args:

{
  config = {
    services.minecraft-servers.servers = lib.pipe (builtins.readDir ./.) [
      (lib.filterAttrs (_name: value: value == "directory"))
      (lib.mapAttrs (name: _type:
        let
          cfg = import ./${name} args;
        in
          {
          } // cfg
      ))
    ];
  };
}
