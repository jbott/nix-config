# Workaround until nix-darwin supports fonts.packages attribute
# Remove when fixed: https://github.com/LnL7/nix-darwin/issues/752
# Inspired by: https://github.com/sei40kr/dotfiles/commit/b5231e715f4a40664f4288467b2ae3c5609c4fc7
{
  config,
  lib,
  options,
  ...
}:
with lib; {
  options.fonts.packages = mkOption {
    type = with types; listOf path;
    default = [];
    description = mkDoc ''
      List of primary font packages.
    '';
  };

  config.fonts.fonts = mkAliasDefinitions options.fonts.packages;
}
