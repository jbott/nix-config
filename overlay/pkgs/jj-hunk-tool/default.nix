{
  lib,
  rustPlatform,
  fetchFromGitHub,
  jujutsu,
}:
rustPlatform.buildRustPackage rec {
  pname = "jj-hunk-tool";
  version = "0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "mvzink";
    repo = "jj-hunk-tool";
    rev = "0fceafeb8d0907790e9fec327df768355b8748d4";
    hash = "sha256-XK6tAXlLUP0kI1UdyQB6ZLY3toRILmmKtQyJ0l4tyeQ=";
  };

  cargoHash = "sha256-8CwA837ybNJ65DlcIwKibKBknUFmZ7+1/UD/HrfYP5k=";

  nativeCheckInputs = [jujutsu];

  meta = {
    description = "Non-interactive hunk level jj operations";
    homepage = "https://github.com/mvzink/jj-hunk-tool";
    license = lib.licenses.mit;
    mainProgram = "jj-hunk-tool";
  };
}
