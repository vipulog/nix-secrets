{
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [
        config.pre-commit.devShell
        config.treefmt.build.devShell
      ];

      packages = with pkgs; [
        sops
        age
        ssh-to-age
      ];
    };
  };
}
