{pkgs, ...}: {
  environment.systemPackages =
    (with pkgs; [
      blueutil
      colima
      docker-client
      m1ddc
    ])
    ++ (with pkgs.darwin; [
      iproute2mac
    ]);
}
