{
  lib,
  stdenvNoCC,
  fetchurl,

  # the full thing will not be available without the overlay
  # but this will suffice for laziness
  minecraftServers,
}:

# TODO: maybe add support for specifiying optional mods
{
  # path with pack.toml at its root
  packRoot,

  # which side mods to install
  side ? "both",
}:

let
  pack = lib.importTOML (lib.path.append packRoot "pack.toml");
  indexPath = lib.path.append packRoot pack.index.file;
  indexRoot = builtins.dirOf indexPath;
  index = lib.importTOML indexPath;

  linkCommands = map (file:
    let
      filePath = lib.path.append indexRoot file.file;
      # treat dest as being relative to / for simplicity
      destPath = lib.path.append /. file.file;
      destRoot = builtins.dirOf destPath;

      fileIsMeta = file.metafile or false;
      meta = lib.importTOML filePath;

      fileSide = if fileIsMeta then meta.side or "both" else "both";
      fileIncluded = fileSide == "both" || side == "both" || fileSide == side;

      src =
        if fileIsMeta then
          fetchurl {
            url = meta.download.url;
            outputHashAlgo = meta.download.hash-format;
            outputHash = meta.download.hash;
          }
        else
          filePath;

      dest =
        if fileIsMeta then
          lib.path.append destRoot meta.filename
        else if file ? alias then
          lib.path.append destRoot file.alias
        else
          file.file;

      relDest = (lib.path.splitRoot dest).subpath;
    in
    lib.optionalString fileIncluded ''
      mkdir -p "$(dirname ${lib.escapeShellArg "${relDest}"})"
      ln -s ${lib.escapeShellArg "${src}"} ${lib.escapeShellArg "${relDest}"}
    ''
  ) index.files;

  supportedLoaders = [ "fabric" "quilt" ];

  serverPackage =
    let
      minecraftVersion = pack.versions.minecraft;
      serverVersion = lib.replaceStrings [ "." ] [ "_" ] minecraftVersion;

      loaderVersions = lib.removeAttrs pack.versions [ "minecraft" ];
      loaders = lib.attrNames loaderVersions;
      hasLoader = lib.length loaders == 1;

      unsupportedLoaders = lib.subtractLists supportedLoaders loaders;

      loader = lib.head loaders;
      loaderVersion = loaderVersions.${loader};
    in
    assert lib.assertMsg (unsupportedLoaders == []) ''
      buildPackwizModpack: the following loaders are currently unsupported:
        - ${lib.concatStringsSep "\n  - " unsupportedLoaders}
    '';
    assert lib.assertMsg (lib.length loaders <= 1) ''
      buildPackwizModpack: multiple mod loader versions are specified:
      ${lib.concatStrings (lib.mapAttrsToList (n: v: "  - ${n}: ${v}" loaders))}
    '';
    if hasLoader then
      minecraftServers."${loader}-${serverVersion}".override {
        inherit loaderVersion;
      }
    else
      minecraftServers."vanilla-${serverVersion}";
in
assert lib.assertMsg (side == "client" || side == "server" || side == "both") ''
  buildPackwizModpack: `side` must be one of "client", "server" or "both"
'';
assert lib.assertMsg (pack.pack-format == "packwiz:1.1.0") ''
  buildPackwizModpack: only packwiz:1.1.0 is supported at the moment
'';
# mostly just manual linkFarm
stdenvNoCC.mkDerivation {
  pname = pack.name;
  version = pack.version;

  enableParallelBuilding = true;

  preferLocalBuild = true;
  allowSubstitutes = false;

  buildCommand = ''
    mkdir -p $out
    cd $out
    ${lib.concatStrings linkCommands}
  '';
  passAsFile = [ "buildCommand" ];

  passthru = {
    packwiz = pack;
    inherit serverPackage;
  };

  meta = {
    description = pack.description or "minecraft modpack";
    sourceProvenance = [
      lib.sourceTypes.binaryBytecode
    ];
  };
}
