{
  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:2023.5.3";
      environment = {
        TZ = "America/Los_Angeles";
      };
      volumes = [
        "/persist/var/lib/home-assistant:/config"
      ];
      ports = [ "8123:8123" ];
    };
  };
}
