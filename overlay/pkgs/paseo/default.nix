{
  lib,
  fetchurl,
  runCommand,
  jq,
  buildNpmPackage,
  nodejs_22,
  python3,
}:
buildNpmPackage {
  pname = "paseo";
  version = "0.4.0";

  # The published @getpaseo/cli tarball ships prebuilt `dist/` JS but no
  # package-lock.json. buildNpmPackage needs BOTH package.json and a lock in
  # `src` before fetchNpmDeps runs, so we splice our vendored lock (generated
  # via `npm install --package-lock-only --omit=dev --ignore-scripts` and then
  # pruned, see below) into the extracted tarball.
  src = runCommand "paseo-cli-src" {nativeBuildInputs = [jq];} ''
    mkdir -p $out
    tar xzf ${fetchurl {
      url = "https://registry.npmjs.org/@getpaseo/cli/-/cli-0.4.0.tgz";
      hash = "sha256-HNunG8XSRfatSGyPPhx0X7dQIMbX+QeIPXhxSoIOoZA=";
    }} --strip-components=1 -C $out
    cp ${./package-lock.json} $out/package-lock.json
    # Drop the package's own lifecycle scripts: clean/build/prepack reference
    # monorepo paths (../../scripts/*.mjs) absent from the published tarball, and
    # npm would run them during install. We ship the prebuilt dist and don't
    # build, so none are needed. Dependency install scripts (e.g. node-pty's
    # node-gyp build) live in their own package.json and are unaffected.
    jq 'del(.scripts)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
  '';

  npmDepsHash = "sha256-N2GmpmX0EXuK5USEkoVTtwK9ZjRyJgd357QCHIxj+aU=";

  # Run under Node 22 (matches upstream engines and the prebuilt dist).
  nodejs = nodejs_22;

  # The transitive native dep node-pty@1.2.0-beta.15 ships a prebuilt pty.node
  # (loads fine — Node already provides libstdc++ in-process, so no autoPatchelf
  # needed). python3 is kept as a fallback so npm can node-gyp-compile it if a
  # future bump drops the prebuild.
  nativeBuildInputs = [python3];

  # dist/ is already-compiled JS. The package's `prepack`/`build` scripts run
  # `tsc`/`tsgo`, which need the (dev-only, un-vendored) TypeScript toolchain
  # and fail in the sandbox. There is nothing to build, so skip npm build.
  dontNpmBuild = true;

  # NOTE: install scripts are intentionally left ENABLED — node-pty must run
  # its node-gyp build to produce pty.node. Do not pass --ignore-scripts here.

  # sherpa-onnx-node (an optional, lazily-required voice dependency loaded in a
  # try/catch — the daemon runs fine without it) pulls per-platform prebuilt
  # binary packages. Those cross-platform blobs are large, so the vendored
  # package-lock.json has been pruned to keep only `sherpa-onnx-linux-x64`
  # (the darwin/win/linux-arm64 entries and their optionalDependencies refs
  # were removed). This keeps fetchNpmDeps lean on x86_64-linux.

  meta = {
    description = "Paseo CLI - control your self-hosted AI coding-agent daemon from the command line";
    homepage = "https://www.npmjs.com/package/@getpaseo/cli";
    license = lib.licenses.mit;
    mainProgram = "paseo";
    platforms = ["x86_64-linux"];
  };
}
