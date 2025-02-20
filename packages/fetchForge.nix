{
  lib,
  fetchurl,
  substitute,
  writeShellApplication,

  openjdk_headless,
}:

lib.makeOverridable (
{
  mcVersion,
  forgeVersion,

  hash,

  serverArgs ? [ "nogui" ],

  jdk ? openjdk_headless,
}:
let
  javaBin = lib.getExe jdk;

  version = "${mcVersion}-${forgeVersion}";

  serverFiles = fetchurl {
    pname = "minecraftforge";
    inherit version hash;

    url = "https://maven.minecraftforge.net/net/minecraftforge/forge/${version}/forge-${version}-installer.jar";
    recursiveHash = true;

    downloadToTemp = true;
    postFetch = ''
      ${javaBin} -jar $downloadedFile -installServer $out
    '';
  };

  launchArgsFile = substitute {
    src = "${serverFiles}/libraries/net/minecraftforge/forge/${version}/unix_args.txt";
    substitutions = [
      "--replace-fail" "libraries" "${serverFiles}/libraries"
    ];
  };

  runServer = writeShellApplication {
    name = "forge-minecraft-server";
    # essentially copies run.sh
    text = ''
      exec ${javaBin} "$@" @${launchArgsFile} ${lib.escapeShellArgs serverArgs}
    '';

    passthru = {
      inherit launchArgsFile serverFiles;
    };
  };
in
runServer)
