{
  perSystem = {pkgs, ...}: {
    packages = {
      sops-enc-check = pkgs.writeShellApplication {
        name = "sops-enc-check";
        text = builtins.readFile ./sops-enc-check.sh;
      };
    };
  };
}
