{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    blueutil
    colima
    docker-client
    finicky
    gen-firefox-profile-launchers
    iproute2mac
    jabracli
    m1ddc
    utm
    # keep-sorted end
  ];
}
