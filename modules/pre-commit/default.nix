{inputs, ...}: {
  imports = [inputs.git-hooks-nix.flakeModule];

  perSystem = {self', ...}: {
    pre-commit.settings = {
      default_stages = ["pre-commit"];

      hooks = {
        check-added-large-files.enable = true;
        check-case-conflicts.enable = true;
        check-executables-have-shebangs.enable = true;
        check-shebang-scripts-are-executable.enable = true;
        check-merge-conflicts.enable = true;
        detect-private-keys.enable = true;
        fix-byte-order-marker.enable = true;
        mixed-line-endings.enable = true;
        trim-trailing-whitespace.enable = true;
        end-of-file-fixer.enable = true;
        check-symlinks.enable = true;
        check-yaml.enable = true;
        treefmt.enable = true;
        statix.enable = true;

        sops-encrypted-check = {
          enable = true;
          name = "sops-encrypted-check";
          description = "Ensure SOPS files are properly encrypted";
          language = "script";
          files = "^secrets/sops/.*\.(yaml|yml|json)$";
          entry = "${self'.packages.sops-enc-check}/bin/sops-enc-check";
        };

        sops-updatekeys = {
          enable = true;
          name = "sops-updatekeys";
          description = "Ensure SOPS keys are up to date";
          language = "script";
          files = "^\\.sops\\.yaml$|^secrets/sops/.*\\.(yaml|yml|json)$";
          entry = "${self'.packages.sops-updatekeys}/bin/sops-updatekeys";
        };
      };
    };
  };
}
