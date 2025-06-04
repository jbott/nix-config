{
  # Enable mosquitto mqtt server
  services.mosquitto.enable = true;

  # Enable zigbee2mqtt
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      frontend.enabled = true;
      homeassistant.enable = true;

      serial = {
        port = "/dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE2250332-if00";
        adapter = "deconz";
      };
    };
  };

  # Use a bind mount to map data onto /persist
  fileSystems."/var/lib/zigbee2mqtt" = {
    device = "/persist/var/lib/zigbee2mqtt";
    options = ["bind"];
  };

  # Open the firewall for the web ui
  networking.firewall.allowedTCPPorts = [8080];
}
