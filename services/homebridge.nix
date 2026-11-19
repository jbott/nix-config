{pkgs, ...}: let
  imageName = "docker.io/homebridge/homebridge";
  imageTag = "2026-11-15";
  imageDigest = "sha256:5a76d945dd24250b1886f13f14fd65bb3ccc8489eaf57a23dd336cff1cf436ba";
  sha256 = "sha256-nZdH6NIgjlECshuGeWdRBCv0Lu5TDRRWJaO1IPjMRQ8=";

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
      extraOptions = [
        "--network=host"
        "--memory=1g"
        "--cpus=0.5"
      ];
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
