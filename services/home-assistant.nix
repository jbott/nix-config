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

  # Enable homekit bridge on all interfaces
  networking.firewall.allowedTCPPorts = [21064];

  # Enable mDNS on all interfaces
  networking.firewall.allowedUDPPorts = [5353];

  # Enable webui on tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8123];
}
