{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    blueutil
    colima
    docker-client
    gen-firefox-profile-launchers
    iproute2mac
    m1ddc
    utm
  ];
}
