# jj support for the Herdr app: patched copies of its shipped mods, built from
# the installed version's defaults so a Herdr update re-applies jj.patch (and
# fails the build if upstream changed those lines). Shipped mods can't be
# edited in place: Herdr restores them on every start.
{
  lib,
  pkgs,
  ...
}: let
  cloned = ["menu" "new-menu" "spaces" "tabs" "worktree"];

  jjMods =
    pkgs.runCommandLocal "herdr-app-jj-mods-${pkgs.herdr-app.version}" {
      nativeBuildInputs = [pkgs.jq];
    } ''
      shipped=${pkgs.herdr-app.src}/defaults
      mkdir -p $out/mods $out/layouts
      for m in ${lib.concatStringsSep " " cloned}; do
        cp -r "$shipped/mods/$m" "$out/mods/jj-$m"
        chmod -R u+w "$out/mods/jj-$m"
        # As `herdr-app do mod.clone` does: a clone's own assets use its new name.
        sed -i "s#mods/$m/#mods/jj-$m/#g" "$out/mods/jj-$m/main.js"
      done
      patch -p1 --fuzz=0 --no-backup-if-mismatch -d $out/mods < ${./jj.patch}
      cp ${./jj.js} $out/mods/jj-spaces/jj.js
      cp ${./jj.js} $out/mods/jj-worktree/jj.js

      jq 'walk(if type == "object" and (.mod == "spaces" or .mod == "tabs") then .mod = "jj-" + .mod else . end)' \
        "$shipped/layouts/main.json" > $out/layouts/jj.json
      [ "$(jq '[.. | objects | select(.mod == "jj-spaces" or .mod == "jj-tabs")] | length' $out/layouts/jj.json)" = 2 ]
    '';
in {
  # recursive: Herdr writes jsconfig.json and gpui-kit.d.ts into mod folders.
  # force: replaces the files `mod.clone` made before these were managed here.
  xdg.configFile =
    lib.listToAttrs (map (m:
      lib.nameValuePair "herdr-app/mods/jj-${m}" {
        source = "${jjMods}/mods/jj-${m}";
        recursive = true;
        force = true;
      })
    cloned)
    // {
      "herdr-app/layouts/jj.json" = {
        source = "${jjMods}/layouts/jj.json";
        force = true;
      };
    };
}
