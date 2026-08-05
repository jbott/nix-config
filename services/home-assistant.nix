{pkgs, ...}: let
  imageName = "ghcr.io/home-assistant/home-assistant";
  imageTag = "2026.7.4";
  imageDigest = "sha256:5a531753cea96444200158fc2b0ac7ccd739291ec50414877b396de6e0bb29b3";
  sha256 = "sha256-tc5W+dLiOtV90TbMtDRGtyRDT/uic78e46SJ508eBfk=";

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
