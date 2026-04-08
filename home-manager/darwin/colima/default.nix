{pkgs, ...}: let
  yaml = pkgs.formats.yaml {};
  settings = {
    cpu = 8;
    memory = 16;
    kubernetes.enabled = true;
    docker.features.containerd-snapshotter = true;
    vmType = "vz";
    rosetta = true;
    mountType = "virtiofs";
  };
in {
  home.file.".colima/_templates/default.yaml".source =
    pkgs.runCommand "colima-template" {
      nativeBuildInputs = [pkgs.yq-go];
    } ''
      yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        ${pkgs.colima.src}/embedded/defaults/colima.yaml \
        ${yaml.generate "colima-overrides.yaml" settings} > $out
    '';
}
