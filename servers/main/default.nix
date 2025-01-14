{ pkgs, ... }:

let
  modpack = pkgs.buildPackwizModpack {
    packRoot = ./.;
    side = "server";
  };
in
{
  serverProperties = {
    server-port = 25565;
    motd = ''this is \u00A7n\u00A7o\u00A7nthe\u00A7r server of \u00A7kthere is nothing\u00A7r'';
  };
  jvmOpts = "-Xmx4G -Xms500M";

  package = modpack.serverPackage;
  symlinks = {
    mods = "${modpack}/mods";
  };
}