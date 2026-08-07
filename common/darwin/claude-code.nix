{pkgs, ...}: let
  managedSettings = import ../claude-code/managed-settings.nix {inherit pkgs;};
  managedDir = "/Library/Application Support/ClaudeCode";
in {
  # nix-darwin has no declarative option for /Library/Application Support, and
  # Claude Code looks for the policy file at a fixed path there, so activation
  # installs it. A copy rather than a store symlink: managed settings are a
  # privilege boundary, and a root-owned regular file avoids depending on how
  # Claude Code resolves symlinks when deciding whether the file is trusted.
  #
  # Not cleaned up if this module is removed — delete the file by hand then.
  system.activationScripts.postActivation.text = ''
    echo "installing Claude Code managed settings..." >&2
    mkdir -p "${managedDir}"
    install -m 0444 ${managedSettings} "${managedDir}/managed-settings.json"
  '';
}
