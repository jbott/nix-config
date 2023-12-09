{pkgs, ...}: {
  services.deconz = {
    enable = true;

    # TODO: make not aarch64 specific
    package = pkgs.deconz-aarch64;

    # Enable listening on all addresses on acceptable ports
    listenAddress = "0.0.0.0";

    # Enable restarting the service inside the UI
    allowRestartService = true;

    # Allow access through firewall TODO: restrict to tailscale interface when
    # home assistant is running on this node
    openFirewall = true;
  };
}
