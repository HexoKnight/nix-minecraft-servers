{ lib, pkgs, ... }:

let
  serverFiles = pkgs.fetchzip rec {
    pname = "atm9sky";
    version = "1.1.5";
    url = "https://mediafilez.forgecdn.net/files/6253/993/server-${version}.zip";
    hash = "sha256-t5QvjPsLYn1EiwZCoET5/f87x7jGZjFPDHWj5Mq7XHk=";
    stripRoot = false;
  };

  serverPackage = pkgs.fetchForge {
    mcVersion = "1.20.1";
    forgeVersion = "47.3.33";
    hash = "sha256-aOugxrl+mahBLQUGezL14o+pogxgx4M+FdoQH4+74K0=";

    jdk = pkgs.openjdk17_headless;
  };

  paths = {
    symlinked = [
    ];
    files = [
      # complains about readonly filesystem otherwise
      "kubejs"
      # done separately to add mods
      # "mods"
      # this needs to be modified at runtime (and config generally need to be writable)
      "config"
      # copying files from this dir makes them readonly if symlinked
      "defaultconfigs"
    ];
  };

  mods =
    let
      extraMods = [
        # https://www.curseforge.com/minecraft/mc-mods/ready-player-fun
        (pkgs.fetchurl {
          url = "https://mediafilez.forgecdn.net/files/5863/625/readyplayerfun-1.20.1-3.0.0.0-FORGE.jar";
          hash = "sha256-HAZ9TBIsDNwyxlpglSuv9X5kXYxThIh/hBw/KlOXgPI=";
        })
      ];
    in
    pkgs.symlinkJoin {
      name = "mods";
      paths = [ "${serverFiles}/mods" ];
      postBuild = lib.concatMapStrings (mod: ''
        ln -s ${mod} $out/${mod.name}
      '') extraMods;
    };

  genPathAttrs = paths: lib.genAttrs paths (path: "${serverFiles}/${path}");

  # https://allthemods.github.io/alltheguides/help/java/#server-arguments
  jvmArgs = builtins.toFile "jvm_args.txt" ''
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1
  '';
in
{
  # default-server.properties
  serverProperties = {
    motd = ''\u00a7f\u00a7lAllTheMods9: To the Sky server'';
    max-tick-time = 180000;
    level-type = ''skyblockbuilder\:skyblock'';
    simulation-distance = 8;
    view-distance = 10;
    allow-flight = true;
    difficulty = "normal";
  };

  jvmOpts = "-Xms4G -Xmx6G @${jvmArgs}";

  package = serverPackage;
  symlinks = genPathAttrs paths.symlinked;
  files = genPathAttrs paths.files // {
    "mods" = mods;
  };
}
