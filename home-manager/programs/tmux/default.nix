{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    extraConfig =
      ''
        # Mauuuuuse
        set -g mouse on

        # Configure vim keybindings for switching panes
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Configure ctrl-vim keybindings for switching windows
        bind C-h previous-window
        bind C-l next-window

        # Configure ctrl-pageup/pagedown keybindings for switching windows
        bind -n C-Pageup previous-window
        bind -n C-Pagedown next-window

        # Auto-rename panes
        set-option -g status-interval 2
        set-option -g automatic-rename on
        set-option -g automatic-rename-format '#{b:pane_current_path}'

        # long scrollback
        set-option -g history-limit 50000

        # Use vim keybindings in copy mode
        setw -g mode-keys vi

        # Wheel scrolling in copy mode
        bind -T copy-mode WheelUpPane send -N1 -X scroll-up
        bind -T copy-mode WheelDownPane send -N1 -X scroll-down
        bind-key -T copy-mode-vi WheelUpPane send -N1 -X scroll-up
        bind-key -T copy-mode-vi WheelDownPane send -N1 -X scroll-down

        # Clear the default command set by tmux-sensible. It's version of reattach-to-user-namespace
        # breaks launching zsh. It also does not work correctly for sudo, and tmux includes this
        # functionality for pbcopy / pbpaste already.
        set-option -g default-command ""
      ''
      + builtins.readFile ./challenger-deep.tmuxtheme;
    terminal = "screen-256color";
  };
}
