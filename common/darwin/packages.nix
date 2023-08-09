{pkgs, ...}: {
  environment.systemPackages =
    (with pkgs; [
      colima
      docker-client
    ])
    ++ (with pkgs.darwin; [
      iproute2mac
    ]);
}
