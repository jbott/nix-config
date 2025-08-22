{
  # Fix for nsncd/nscd service failures
  # See: https://github.com/NixOS/nixpkgs/issues/259352
  # See: https://github.com/NixOS/nixpkgs/issues/432251

  # Create the /run/nscd directory that the service expects
  systemd.tmpfiles.rules = [
    "d /run/nscd 0755 root root - -"
  ];

  # Optionally disable nsncd and use traditional nscd if issues persist
  # services.nscd.enableNsncd = false;
}
