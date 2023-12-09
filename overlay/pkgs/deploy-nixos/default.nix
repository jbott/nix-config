{
  nixos-rebuild,
  writeShellApplication,
}:
writeShellApplication {
  name = "deploy-nixos";
  runtimeInputs = [nixos-rebuild];
  text = builtins.readFile ./deploy-nixos.sh;
}
