{pkgs, ...}: let
  imageName = "ghcr.io/home-assistant/home-assistant";
  imageTag = "2026.11.2";
  imageDigest = "sha256:493a07e8f6530fc640223f4a0a5248f20a61ca2f718bb1d31efbf08a2c5ea28f";
  sha256 = "sha256-nbzk4GAvu3fxlwOIeOX1yAxebiMFSAB6I0j6LgAiBHk=";

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
      extraOptions = [
        "--network=host"
        "--memory=2g"
        "--cpus=1"
      ];
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
