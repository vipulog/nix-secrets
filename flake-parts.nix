{lib, ...}: {
  imports = [
    ./pre-commit.nix
    ./treefmt.nix
    ./shell.nix
    ./packages.nix
  ];

  flake = let
    nixSecretsDir = ./secrets/nix;
    nixSecretFiles = builtins.attrNames (builtins.readDir nixSecretsDir);

    importNixSecret = name: import "${nixSecretsDir}/${name}" {inherit lib;};
    removeNixSuffix = name: builtins.replaceStrings [".nix"] [""] name;

    mkSecret = name: {
      name = removeNixSuffix name;
      value = importNixSecret name;
    };
  in {
    secrets = builtins.listToAttrs (map mkSecret nixSecretFiles);
  };
}
