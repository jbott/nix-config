# The Herdr app, set up like tmux was. jj support: patched copies of its
# shipped mods, built from the installed version's defaults so a Herdr update
# re-applies jj.patch (and fails the build if upstream changed those lines).
# Shipped mods can't be edited in place: Herdr restores them on every start.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # tmux's keys for getting around (../tmux): windows are Herdr's tabs, and
  # ctrl-b ctrl-k/j go up and down the spaces sidebar. A ctrl-b not followed
  # by one of these reaches the program after a second.
  tmuxKeys = {
    "ctrl-b h" = "pane.go:left";
    "ctrl-b j" = "pane.go:down";
    "ctrl-b k" = "pane.go:up";
    "ctrl-b l" = "pane.go:right";
    "ctrl-b z" = "pane.zoom";
    "ctrl-b ctrl-h" = "tab.prev";
    "ctrl-b ctrl-l" = "tab.next";
    "ctrl-b ctrl-k" = "space.prev";
    "ctrl-b ctrl-j" = "space.next";
    "ctrl-pageup" = "tab.prev";
    "ctrl-pagedown" = "tab.next";
  };

  # Herdr's own macOS keys plus tmux's, so a Herdr update's new defaults come too.
  keys =
    pkgs.runCommandLocal "herdr-app-keys-${pkgs.herdr-app.version}" {
      nativeBuildInputs = [pkgs.jq];
      tmuxKeys = builtins.toJSON tmuxKeys;
    } ''
      jq --argjson tmux "$tmuxKeys" '.global += $tmux' ${pkgs.herdr-app.src}/defaults/keys.macos.json > $out
    '';

  cloned = ["agents" "menu" "new-menu" "spaces" "tabs" "worktree"];

  # jj-agents names each agent the way tmux named windows.
  jjTitle = pkgs.writeShellScript "jj-title" (builtins.readFile ../tmux/jj-title.sh);

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
      substituteInPlace $out/mods/jj-agents/main.js --replace-fail @jjTitle@ ${jjTitle}

      jq 'walk(if type == "object" and (.mod == "agents" or .mod == "spaces" or .mod == "tabs") then .mod = "jj-" + .mod else . end)
        | .theme = {light: "paper", dark: "challenger-deep"}' \
        "$shipped/layouts/main.json" > $out/layouts/jj.json
      [ "$(jq '[.. | objects | select(.mod == "jj-agents" or .mod == "jj-spaces" or .mod == "jj-tabs")] | length' $out/layouts/jj.json)" = 3 ]
    '';
in {
  # A copy, not a link: Herdr reloads keys.json when its mtime changes, and
  # every store path has the same one. Renamed into place so Herdr never sees
  # it missing (it would write its defaults).
  home.activation.herdrAppKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
    dest="${config.xdg.configHome}/herdr-app/keys.json"
    if ! ${pkgs.diffutils}/bin/cmp -s ${keys} "$dest"; then
      run mkdir -p "$(dirname "$dest")"
      run install -m 644 ${keys} "$dest.nix-new"
      run mv -f "$dest.nix-new" "$dest"
    fi
  '';

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
      # Challenger Deep, as in neovim and tmux: Ghostty's bundled palette, with
      # the vim theme's Visual color for selection (Ghostty's is the foreground).
      "herdr-app/themes/challenger-deep.json" = {
        source = ./challenger-deep.json;
        force = true;
      };
    };
}
