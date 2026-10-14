{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    blueutil
    colima
    docker-client
    finicky
    iproute2mac
    m1ddc
    utm
    # keep-sorted end
  ];
}
