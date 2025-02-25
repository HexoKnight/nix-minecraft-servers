{ lib, pkgs, ... }:

let
  javaBin = lib.getExe pkgs.openjdk8;

  serverFiles = pkgs.fetchzip rec {
    name = "SkyFactory-4_Server_4_2_4";
    url = "https://mediafilez.forgecdn.net/files/3565/687/${name}.zip";
    hash = "sha256-kz4DF/ADHmbNZqi2S7E2qMYiXgVC+k5qnV/xyOZb/yM=";
    stripRoot = false;

    postFetch = ''
      cd $out
      ${javaBin} -jar $out/forge-1.12.2-14.23.5.2860-installer.jar --installServer $out
      rm $out/forge-1.12.2-14.23.5.2860-installer.jar
      # the log contains some illegal paths
      rm $out/forge-1.12.2-14.23.5.2860-installer.jar.log
    '';
  };

  paths = {
    symlinked = [
      "fontfiles"
      "libraries"
      "oresources"
      "resources"
      "server-icon.png"
      # old forge is a bit irritating
      "forge-1.12.2-14.23.5.2860.jar"
      "minecraft_server.1.12.2.jar"
    ];
    files = [
      # creates mods at runtime???
      # also done separately to add mods
      # "mods"
      # this needs to be modified at runtime (and config generally need to be writable)
      "config"
      # craftteaker tries to create this dir
      "scripts"
    ];
  };

  mods =
    let
      extraMods = [
        # https://www.curseforge.com/minecraft/mc-mods/serverpauser
        (pkgs.fetchurl {
          url = "https://mediafilez.forgecdn.net/files/4525/718/Server-Pauser-1.12.2-1.0.0.jar";
          hash = "sha256-XTgUo468tGwBLrM+VZtaKHGWc6560qRRXN7HBRCwEAA=";
        })

        # https://www.curseforge.com/minecraft/mc-mods/p455w0rds-library
        (pkgs.fetchurl {
          url = "https://mediafilez.forgecdn.net/files/2830/265/p455w0rdslib-1.12.2-2.3.161.jar";
          hash = "sha256-5YRMBE2fLOLyPu+E2V7qjMHyxVgYdL0BQQ59EDuQpCQ=";
        })
        # https://www.curseforge.com/minecraft/mc-mods/ae2wtlib
        # depends on prev
        (pkgs.fetchurl {
          url = "https://mediafilez.forgecdn.net/files/2830/114/AE2WTLib-1.12.2-1.0.34.jar";
          hash = "sha256-bQ7FRb+U5hQrQUD5EKrkEUsfkimOggwS+pGvNaPJDWA=";
        })
        # https://www.curseforge.com/minecraft/mc-mods/wireless-crafting-terminal
        # depends on prev 2
        (pkgs.fetchurl {
          url = "https://mediafilez.forgecdn.net/files/2830/252/WirelessCraftingTerminal-1.12.2-3.12.97.jar";
          hash = "sha256-aeW4LzOSUWnjNFal9rMgKRfAb8NPHzL3HPVTsHM/ARQ=";
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

  patches = [
    {
      path = "config/aroma1997/aromabackup.cfg";
      sedExpr = ''s/(S:compressionType=).*$/\1tar.gz/'';
    }
  ];

  genPathAttrs = paths: lib.genAttrs paths (path: "${serverFiles}/${path}");

  # essentially copies run.sh
  serverPackage = pkgs.writeShellApplication {
    name = "skyfactory4-minecraft-server";
    text = ''
      exec ${javaBin} -server "$@" -XX:+UseG1GC -Dsun.rmi.dgc.server.gcInterval=2147483646 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -Dfml.readTimeout=180 -jar forge-1.12.2-14.23.5.2860.jar nogui
    '';
  };
in
{
  serverProperties = {
    motd = ''\u00A7d\u00A7oSkyFactory 4\: Server\u00A7r - \u00A74v4.2.4'';

    # from server.properties (with defaults commented out)
    allow-flight = true;
    # allow-nether = true;
    # broadcast-console-to-ops = true;
    # difficulty = 1;
    enable-command-block = true;
    # enable-query = false;
    # enable-rcon = false;
    # force-gamemode = false;
    # gamemode = 0;
    # generate-structures = true;
    generator-settings = ''{"Topography-Preset"\:"Sky Factory 4"}'';
    # hardcore = false;
    # level-name = "world";
    # level-seed = "";
    # level-type = "DEFAULT";
    # dunno if this is the default for 1.12
    # max-build-height = 256;
    # max-players = 20;
    # max-tick-time = 60000;
    # max-world-size = 29999984;
    # network-compression-threshold = 256;
    # online-mode = true;
    # op-permission-level = 4;
    # player-idle-timeout = 0;
    # prevent-proxy-connections = false;
    # pvp = true;
    # resource-pack = "";
    # resource-pack-sha1 = "";
    # server-ip = "";
    # server-port = 25565;
    # dunno if this is the default for 1.12
    # snooper-enabled = true;
    # dunno if this is the default for 1.12
    # spawn-animals = true;
    # spawn-monsters = true;
    # dunno if this is the default for 1.12
    # spawn-npcs = true;
    spawn-protection = 0;
    # view-distance = 10;
    # white-list = false;
  };
  jvmOpts = "-Xmx4G -Xms500M";

  extraStartPre = lib.concatMapStrings (patch: ''
    if [ -f ${lib.escapeShellArg patch.path} ]; then
      ${lib.getExe pkgs.gnused} -i -Ee ${lib.escapeShellArg patch.sedExpr} ${lib.escapeShellArg patch.path}
    fi
  '') patches;

  package = serverPackage;
  symlinks = genPathAttrs paths.symlinked;
  files = genPathAttrs paths.files // {
    "mods" = mods;
  };
}
