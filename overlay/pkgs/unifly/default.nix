{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  lld,
  autoPatchelfHook,
  stdenv,
}:
rustPlatform.buildRustPackage rec {
  pname = "unifly";
  version = "0.9.1";

  src = fetchFromGitHub {
    owner = "hyperb1iss";
    repo = "unifly";
    rev = "v${version}";
    hash = "sha256-u+nERyym51tPD13QGNO0XeqPse+qydWT9wudpwfJuso=";
  };

  cargoHash = "sha256-71kQ6Rv79ehW2h4cmD0L3DGOC3sfv4Qw1KK0KNN/c/g=";

  nativeBuildInputs =
    [pkg-config lld]
    ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [dbus stdenv.cc.cc.lib];

  doCheck = false;

  meta = {
    description = "Command-line interface for UniFi Network controllers";
    homepage = "https://github.com/hyperb1iss/unifly";
    license = lib.licenses.asl20;
    mainProgram = "unifly";
  };
}
