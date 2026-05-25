{
  perSystem = {pkgs, ...}: {
    packages = {
      sops-updatekeys = pkgs.writeShellApplication {
        name = "sops-updatekeys";
        runtimeInputs = [pkgs.sops pkgs.findutils];

        text = ''
          for file in "$@"; do
            if [[ "$file" == ".sops.yaml" ]]; then
              if [[ -d "secrets/sops" ]]; then
                find secrets/sops -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) -exec sops updatekeys -y {} +
              fi
            elif [[ -f "$file" ]]; then
              sops updatekeys -y "$file"
            fi
          done
        '';
      };
    };
  };
}
