{config, ...}: let
  user = config.system.primaryUser;
  volume = "Lima";
in {
  # nix-darwin has no declarative option for APFS volumes, so activation
  # creates one for Lima's state (VM disks included) if it doesn't exist yet.
  # It goes in the boot volume's container, sharing its free space, and macOS
  # mounts it at /Volumes/${volume} on every boot. home-manager points
  # LIMA_HOME at it.
  #
  # Not cleaned up if this module is removed: delete the volume by hand with
  # `diskutil apfs deleteVolume ${volume}`.
  system.activationScripts.postActivation.text = ''
    if ! diskutil info -plist "${volume}" >/dev/null 2>&1; then
      echo "creating APFS volume ${volume}..." >&2
      container=$(diskutil info -plist / | plutil -extract APFSContainerReference raw -)
      diskutil apfs addVolume "$container" APFS "${volume}" >/dev/null
    elif [[ ! -d "/Volumes/${volume}" ]]; then
      diskutil mount "${volume}" >/dev/null
    fi
    chown ${user}:staff "/Volumes/${volume}"
  '';
}
