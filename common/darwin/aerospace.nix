{lib, ...}: let
  mod = "alt";

  workspaces = map toString (lib.range 1 9);
in {
  # Mirrors AeroSpace's default-config.toml, trimmed to numbered workspaces.
  # A config file replaces the default bindings wholesale (other keys fall
  # back per key), so every binding has to be listed here.
  services.aerospace = {
    enable = true;
    settings = {
      config-version = 2;

      # A newly connected monitor gets an off-screen workspace already assigned
      # to it; failing that, the lowest-numbered empty workspace that is neither
      # persistent nor pinned. The default config makes every bound workspace
      # persistent, so external displays came up as 10, 11 (unbound).
      #
      # So pin 1 to the first external and leave 2-9 non-persistent, so other
      # displays get the lowest free one. 1 must be persistent for the pin to
      # find it; with no external connected the pin is ignored.
      persistent-workspaces = ["1"];
      # A name pattern resolves to the leftmost matching monitor.
      workspace-to-monitor-force-assignment."1" = "^(?!built-in)";

      mode.main.binding =
        {
          "${mod}-slash" = "layout tiles horizontal vertical";
          "${mod}-comma" = "layout accordion horizontal vertical";
          "${mod}-shift-space" = "layout floating tiling";

          "${mod}-h" = "focus left";
          "${mod}-j" = "focus down";
          "${mod}-k" = "focus up";
          "${mod}-l" = "focus right";

          "${mod}-shift-h" = "move left";
          "${mod}-shift-j" = "move down";
          "${mod}-shift-k" = "move up";
          "${mod}-shift-l" = "move right";

          # Option-arrow moves by word in macOS.
          "ctrl-${mod}-left" = "focus-monitor left";
          "ctrl-${mod}-down" = "focus-monitor down";
          "ctrl-${mod}-up" = "focus-monitor up";
          "ctrl-${mod}-right" = "focus-monitor right";

          "ctrl-${mod}-shift-left" = "move-node-to-monitor --focus-follows-window left";
          "ctrl-${mod}-shift-down" = "move-node-to-monitor --focus-follows-window down";
          "ctrl-${mod}-shift-up" = "move-node-to-monitor --focus-follows-window up";
          "ctrl-${mod}-shift-right" = "move-node-to-monitor --focus-follows-window right";

          "${mod}-minus" = "resize smart -50";
          "${mod}-equal" = "resize smart +50";

          "${mod}-tab" = "workspace-back-and-forth";
          "${mod}-shift-tab" = "move-workspace-to-monitor --wrap-around next";

          "${mod}-shift-semicolon" = "mode service";
        }
        // lib.listToAttrs (lib.concatMap (ws: [
            (lib.nameValuePair "${mod}-${ws}" "workspace ${ws}")
            (lib.nameValuePair "${mod}-shift-${ws}" "move-node-to-workspace ${ws}")
          ])
          workspaces);

      mode.service.binding = {
        esc = ["reload-config" "mode main"];
        r = ["flatten-workspace-tree" "mode main"]; # reset layout
        f = ["layout floating tiling" "mode main"];
        backspace = ["close-all-windows-but-current" "mode main"];

        "${mod}-shift-h" = ["join-with left" "mode main"];
        "${mod}-shift-j" = ["join-with down" "mode main"];
        "${mod}-shift-k" = ["join-with up" "mode main"];
        "${mod}-shift-l" = ["join-with right" "mode main"];
      };
    };
  };

  # AeroSpace parks hidden windows in a screen corner, which Mission Control
  # renders tiny; grouping by app works around it (per the AeroSpace guide).
  system.defaults.dock.expose-group-apps = true;
}
