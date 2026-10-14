{lib, ...}: {
  # Enable mosquitto mqtt server
  services.mosquitto.enable = true;

  # Enable zigbee2mqtt
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      frontend.enabled = true;
      homeassistant = lib.mkForce true;

      serial = {
        port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_30012bfc3f53ef11b8ba28e0174bec31-if00-port0";
        adapter = "ember";
      };
    };
  };

  environment.persistence."/persist".directories = ["/var/lib/zigbee2mqtt"];

  # Open the firewall for the web ui
  networking.firewall.allowedTCPPorts = [8080];
}
