{pkgs, ...}: let
  imageName = "docker.io/homebridge/homebridge";
  imageTag = "2026-05-13";
  imageDigest = "sha256:36d43ed9711e37fba7a2ab82165c8f3b199398fd6d491c9eeaf289d43850e927";
  sha256 = "sha256-boHm3odcXklObiJcQMFtQm+K0IDeyUh2crPIew47El0=";

  image = "${imageName}:${imageTag}";
  imageFile = pkgs.dockerTools.pullImage {
    inherit imageName imageDigest sha256;
    finalImageTag = imageTag;
  };
in {
  virtualisation.oci-containers = {
    containers.homebridge = {
      inherit image imageFile;
      environment = {
        TZ = "America/Los_Angeles";
      };
      volumes = [
        "/persist/var/lib/homebridge:/homebridge"
      ];
      extraOptions = ["--network=host"];
    };
  };

  networking.firewall.allowedTCPPorts = [
    8581 # webui
    51520 # homekit bridge
  ];

  networking.firewall.allowedUDPPorts = [
    5353 # mdns
  ];
}
