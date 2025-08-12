{
  system.defaults = {
    screencapture = {
      location = "~/Pictures/Screenshots";
    };
  };

  home-manager.users.jbo.home.file."Pictures/Screenshots/.keep".text = "";
}
