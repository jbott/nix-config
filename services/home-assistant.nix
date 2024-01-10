{pkgs, ...}: let
  imageName = "ghcr.io/home-assistant/home-assistant";
  imageTag = "2024.1.2";
  imageDigest = "sha256:59c89e5b6c0db63b8a7705f82fcb12dfda41b1c94a63ad9430b70f55106706d8";
  sha256 = "sha256-MrreRklXYrBONIAfN8ShFcMiELL1aBpYuylOJ+MlUa4=";

  image = "${imageName}:${imageTag}";
  imageFile = pkgs.dockerTools.pullImage {
    inherit imageName imageDigest sha256;
    finalImageTag = imageTag;
  };
in {
  virtualisation.oci-containers = {
    backend = "podman";
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
  networking.firewall.allowedTCPPorts = [21212];
  networking.firewall.allowedUDPPorts = [5353];

  # Enable webui on tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8123];
}
