{pkgs, ...}: let
  imageName = "ghcr.io/home-assistant/home-assistant";
  imageTag = "2025.3.3";
  imageDigest = "sha256:f34de69aff7b21c7d7d474b86bef4dbce9613668b8d4a936e6c93b3844611505";
  sha256 = "sha256-cHwl7KPTHq2M5P33LzWZjthr2OcvzhDgDoY3ib4GtXg=";

  image = "${imageName}:${imageTag}";
  imageFile = pkgs.dockerTools.pullImage {
    inherit imageName imageDigest sha256;
    finalImageTag = imageTag;
  };
in {
  virtualisation.oci-containers = {
    containers.home-assistant = {
      inherit image imageFile;
      environment = {
        TZ = "America/Los_Angeles";
      };
      volumes = [
        "/persist/var/lib/home-assistant:/config"
      ];
      extraOptions = ["--network=host"];
    };
  };

  networking.firewall.allowedTCPPorts = [
    8123 # webui
    21064 # homekit bridge
  ];

  networking.firewall.allowedUDPPorts = [
    5353 # mdns
  ];
}
