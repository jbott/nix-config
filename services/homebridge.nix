{pkgs, ...}: let
  imageName = "docker.io/homebridge/homebridge";
  imageTag = "2025-02-26";
  imageDigest = "sha256:97d5c72d3eaf5f5241934feecd07e15704af218819696c1bd867b7b3a6953b3c";
  sha256 = "sha256-UP2oFOOS9i5oePwNUr0xt8TM7EZBajdXczPbu+BfoKs=";

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
