{pkgs, ...}: let
  imageName = "ghcr.io/home-assistant/home-assistant";
  imageTag = "2026.5.3";
  imageDigest = "sha256:ff875078181a0383bf3fca9f061be12d6180896dbd531de04e094e25505b0bb9";
  sha256 = "sha256-BGiEDtZUEnq/W6rwI2lpwtEAEV2IdWM7yvsDYih3UOI=";

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
    21066
    21067
  ];

  networking.firewall.allowedUDPPorts = [
    5353 # mdns
  ];
}
