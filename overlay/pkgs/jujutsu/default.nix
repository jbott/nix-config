{
  fetchFromGitHub,
  jujutsu,
  rustPlatform,
}:
jujutsu.overrideAttrs (finalAttrs: previousAttrs: {
  version = "0.45.1-${builtins.substring 0 12 finalAttrs.src.rev}";

  src = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    rev = "e6dd2c0d60f22ef8d21d171b5fb8e4178f0af1d9";
    hash = "sha256-OSVbzif/+F/RW3fBlqDmEp7Z7yeFXe2jfc7X4qiY92M=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-x3fffc8P15LwKkq3M2j3wA3YRxUYTCL69qfD6SkI/j0=";
  };

  env =
    previousAttrs.env
    // {
      NIX_JJ_GIT_HASH = finalAttrs.src.rev;
    };

  meta =
    previousAttrs.meta
    // {
      changelog = "https://github.com/jj-vcs/jj/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    };
})
