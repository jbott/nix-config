{pkgs, ...}: {
  environment.systemPackages =
    (with pkgs; [
      blueutil
      colima
      docker-client
      iproute2mac
      m1ddc
      utm
    ]);
}
