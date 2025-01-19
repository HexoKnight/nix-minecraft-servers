{ lib, pkgs, ... }:

let
  javaBin = lib.getExe pkgs.openjdk17_headless;

  serverFiles = pkgs.fetchzip rec {
    name = "DeceasedCraft_Server_v5.5.5";
    url = "https://mediafilez.forgecdn.net/files/5525/543/${name}.zip";
    hash = "sha256-97828nAAJd/BnsVh+Cnuv8iVphVUIaOTMF32/uL7GhU=";
    stripRoot = true;

    postFetch = ''
      ${javaBin} -jar $out/forge-1.18.2-40.2.4-installer.jar --installServer $out
      rm $out/forge-1.18.2-40.2.4-installer.jar
    '';
  };

  paths = {
    symlinked = [
      "kubejs"
      "libraries"
      # done separately to change mods
      # "mods"
      "resources"
    ];
    files = [
      # this needs to be modified at runtime (and config generally need to be writable)
      "config"
      # copying files from this dir makes them readonly if symlinked
      "defaultconfigs"
      # craftteaker tries to create this dir
      "scripts"
    ];
  };

  mods =
    let
      newerReadyPlayerFun = pkgs.fetchurl {
        url = "https://mediafilez.forgecdn.net/files/5863/570/ReadyPlayerFun-1.18.2-3.0.0.0.jar";
        hash = "sha256-5PjO/3LosZMyubjiWwbV88JFPXuNp+ITnPG9mGsQuJs=";
      };
    in
    pkgs.symlinkJoin {
      name = "mods";
      paths = [ "${serverFiles}/mods" ];
      postBuild = ''
        cd $out
        rm ReadyPlayerFun-1.18.2-1.4.1.9.jar
        ln -s ${newerReadyPlayerFun} ${newerReadyPlayerFun.name}
      '';
    };

  voicechat = {
    path = "config/voicechat/voicechat-server.properties";
    port = 24455;
  };

  genPathAttrs = paths: lib.genAttrs paths (path: "${serverFiles}/${path}");

  # essentially copies run.sh
  serverPackage = pkgs.writeShellApplication {
    name = "deceasedcraft-minecraft-server";
    text = ''
      exec ${javaBin} "$@" @libraries/net/minecraftforge/forge/1.18.2-40.2.4/unix_args.txt nogui
    '';
  };
in
{
  serverProperties = {
    motd = ''come play \u00A7mProject Zomboid\u00A7r \u00A7lDeceasedCraft!!\u00A7r'';

    # from default-server.properties
    allow-flight = true;
    allow-nether = false;
    enable-command-block = true;
    spawn-protection = 12;
    max-tick-time = 600000;
  };
  jvmOpts = "-Xmx6G -Xms500M";

  extraStartPre = ''
    if [ -e ${voicechat.path} ]; then
      ${lib.getExe pkgs.gnused} -iEe 's/^port=.*$/port=${toString voicechat.port}/' ${voicechat.path}
    fi
  '';

  package = serverPackage;
  symlinks = genPathAttrs paths.symlinked // {
    "mods" = mods;
  };
  files = genPathAttrs paths.files;
}
