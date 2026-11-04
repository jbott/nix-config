# The Herdr app, set up like tmux was. jj support: patched copies of its
# shipped mods, built from the installed version's defaults so a Herdr update
# re-applies jj.patch (and fails the build if upstream changed those lines),
# plus a sidebar of our own (jj-sidebar). Shipped mods can't be edited in
# place: Herdr restores them on every start.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # tmux's keys (../tmux): windows are Herdr's tabs, and ctrl-b ctrl-k/j go up
  # and down the spaces (in the jj layout, its tabs: jjLayoutKeys). A ctrl-b not
  # followed by one of these reaches the program after a second.
  tmuxKeys = {
    "ctrl-b c" = "tab.new";
    "ctrl-b %" = "pane.split:right";
    "ctrl-b \"" = "pane.split:down";
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

  # In the jj layout the sidebar lists every tab, so ctrl-b ctrl-j/k go down and
  # up it a tab at a time, across spaces (other layouts keep space.next/prev),
  # and tmux's other next and previous window keys do the same. Herdr's cmd-]
  # and cmd-[ go through every agent; with shift (Herdr's next and previous
  # tab, which those keys do here), only the ones blocked or done.
  jjLayoutKeys = {
    "ctrl-b ctrl-j" = "jj-sidebar.next";
    "ctrl-b ctrl-k" = "jj-sidebar.prev";
    "ctrl-b ctrl-l" = "jj-sidebar.next";
    "ctrl-b ctrl-h" = "jj-sidebar.prev";
    "ctrl-pagedown" = "jj-sidebar.next";
    "ctrl-pageup" = "jj-sidebar.prev";
    "cmd-shift-]" = "jj-sidebar.waiting-next";
    "cmd-shift-[" = "jj-sidebar.waiting-prev";
  };

  # Herdr's own macOS keys plus tmux's, so a Herdr update's new defaults come too.
  keys =
    pkgs.runCommandLocal "herdr-app-keys-${pkgs.herdr-app.version}" {
      nativeBuildInputs = [pkgs.jq];
      tmuxKeys = builtins.toJSON tmuxKeys;
      jjLayoutKeys = builtins.toJSON jjLayoutKeys;
    } ''
      jq --argjson tmux "$tmuxKeys" --argjson jj "$jjLayoutKeys" \
        '.global += $tmux | ."layout:jj" += $jj' ${pkgs.herdr-app.src}/defaults/keys.macos.json > $out
    '';

  cloned = ["menu" "new-menu" "worktree"];
  # Ours, not clones: jj-sidebar is the sidebar as a vertical tab list (spaces,
  # their tabs, the tabs' agents), in place of the spaces and agents panels
  # and the tab bar.
  own = ["sidebar"];

  # jj-sidebar names tabs the way tmux named windows.
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
      cp -r ${./jj-sidebar} $out/mods/jj-sidebar
      chmod -R u+w $out/mods/jj-sidebar
      cp ${./jj.js} $out/mods/jj-sidebar/jj.js
      cp ${./jj.js} $out/mods/jj-worktree/jj.js
      substituteInPlace $out/mods/jj-sidebar/main.js --replace-fail @jjTitle@ ${jjTitle}

      # main, with jj-sidebar in place of the spaces and agents lists (and in
      # the footer, which gains the tab bar's Files and Changes buttons), and
      # no tab bar.
      jq 'walk(
            if type == "object" and .id == "sidebar-lists" then {id: "tree", type: "block", content: {mod: "jj-sidebar"}}
            elif type == "object" and .id == "sidebar-footer" then .content = {mod: "jj-sidebar", props: {footer: true}}
            elif type == "object" and .id == "work" then .children |= map(select(.id != "tabs"))
            else . end)
        | .theme = {light: "paper", dark: "challenger-deep"}' \
        "$shipped/layouts/main.json" > $out/layouts/jj.json
      jq -e '[.. | objects | select(.mod == "jj-sidebar")] | length == 2' $out/layouts/jj.json
      jq -e '[.. | objects | select(.id == "tabs" or .mod == "spaces" or .mod == "agents" or .mod == "tabs")] | length == 0' $out/layouts/jj.json
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

  # Option types its character (Option-dash is an en dash), as Ghostty's left
  # Option does. Herdr's default, auto, makes Option Alt on US layouts, and it
  # has no left/right split like Ghostty's macos-option-as-alt = "right".
  # Merged in, not linked: Herdr writes this file itself (the zoom keys).
  home.activation.herdrAppSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    dest="${config.xdg.configHome}/herdr-app/settings.json"
    if [ "$(${pkgs.jq}/bin/jq -r '.option_as_alt // ""' "$dest" 2>/dev/null)" != off ]; then
      new=$(mktemp)
      if [ -e "$dest" ]; then
        ${pkgs.jq}/bin/jq '.option_as_alt = "off"' "$dest" > "$new"
      else
        ${pkgs.jq}/bin/jq -n '{option_as_alt: "off"}' > "$new"
      fi
      run mkdir -p "$(dirname "$dest")"
      run install -m 644 "$new" "$dest.nix-new"
      run mv -f "$dest.nix-new" "$dest"
      rm -f "$new"
    fi
  '';

  # The layout and the mods' files are copies, not links, each renamed into
  # place only when it differs. The mods: Herdr won't import a module (jj.js)
  # that resolves outside its mod's folder, and a link into the store does;
  # file by file, as Herdr writes jsconfig.json and gpui-kit.d.ts in there too.
  # The layout: home-manager swaps a link by removing it first, and a shown
  # layout that disappears makes Herdr switch to another one. Before
  # linkGeneration, so the links older generations made here are already
  # files when it cleans up (it leaves those alone).
  home.activation.herdrAppFiles = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
    herdrPut() {
      if [ -L "$2" ] || ! ${pkgs.diffutils}/bin/cmp -s "$1" "$2"; then
        run install -m 644 "$1" "$2.nix-new"
        run mv -f "$2.nix-new" "$2"
      fi
    }
    herdr="${config.xdg.configHome}/herdr-app"
    run mkdir -p "$herdr/layouts"
    herdrPut ${jjMods}/layouts/jj.json "$herdr/layouts/jj.json"
    for m in ${lib.concatMapStringsSep " " (m: "jj-${m}") (cloned ++ own)}; do
      run mkdir -p "$herdr/mods/$m"
      for f in ${jjMods}/mods/$m/*; do
        herdrPut "$f" "$herdr/mods/$m/''${f##*/}"
      done
    done
  '';

  xdg.configFile = {
    # Challenger Deep, as in neovim and tmux: Ghostty's bundled palette, with
    # the vim theme's Visual color for selection (Ghostty's is the foreground).
    "herdr-app/themes/challenger-deep.json" = {
      source = ./challenger-deep.json;
      force = true;
    };
  };
}
