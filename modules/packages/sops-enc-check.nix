{
  perSystem = {pkgs, ...}: {
    packages = {
      sops-enc-check = pkgs.writeShellApplication {
        name = "sops-enc-check";
        runtimeInputs = [pkgs.sops];

        text = ''
          failed=0

          for file in "$@"; do
            if ! sops filestatus "$file" 2>/dev/null | grep -q '"encrypted":true'; then
              echo "ERROR: $file is not a valid SOPS-encrypted file!" >&2
              failed=1
            fi
          done

          exit "$failed"
        '';
      };
    };
  };
}
