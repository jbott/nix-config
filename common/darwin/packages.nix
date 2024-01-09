{pkgs, ...}: {
  environment.systemPackages =
    (with pkgs; [
      blueutil
      colima
      docker-client
    ])
    ++ (with pkgs.darwin; [
      iproute2mac
    ]);
}
