{pkgs, ...}: let
  yaml = pkgs.formats.yaml {};
  settings = {
    cpu = 8;
    memory = 8;
    kubernetes.enabled = true;
    docker.features.containerd-snapshotter = true;
    vmType = "vz";
    rosetta = true;
    mountType = "virtiofs";
  };
in {
  # Lima state (VM disks included) lives on a dedicated APFS volume, created
  # by nix-darwin activation (common/darwin/lima.nix). Colima and limactl
  # both honour LIMA_HOME.
  home.sessionVariables.LIMA_HOME = "/Volumes/Lima";

  home.file.".colima/_templates/default.yaml".source =
    pkgs.runCommand "colima-template" {
      nativeBuildInputs = [pkgs.yq-go];
    } ''
      yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        ${pkgs.colima.src}/embedded/defaults/colima.yaml \
        ${yaml.generate "colima-overrides.yaml" settings} > $out
    '';
}
