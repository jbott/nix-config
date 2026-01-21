{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    usbutils
    # keep-sorted end
  ];
}
