{
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
      ''
      + builtins.readFile ./challenger-deep.tmuxtheme;
    terminal = "tmux-256color";
  };
}
