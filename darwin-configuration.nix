{ config, pkgs, ... }:

let
  vim-challenger-deep-theme = pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "vim-challenger-deep-theme";
    src = pkgs.fetchFromGitHub {
      owner = "challenger-deep-theme";
      repo = "vim";
      rev = "e3d5b7d9711c7ebbf12c63c2345116985656da0d";
      hash = "sha256-2lIPun5OjaoHSG2BdnX9ztw3k9whVlBa9eB2vS8Htbg=";
    };
  };
in
{
  imports = [ <home-manager/nix-darwin> ];

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    alacritty
    atuin
    fd
    git
    jq
    neovim
    nodePackages.prettier
    python311
    ripgrep
    starship
    tmux
    watch
    wget
    yubikey-manager
    zsh
  ];

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command flakes" ];

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Enable pam_tid.so
  security.pam.enableSudoTouchIdAuth = true;

  # Fonts
  fonts.fontDir.enable = true;
  fonts.fonts = with pkgs; [
     recursive
     (nerdfonts.override { fonts = [ "SourceCodePro" ]; })
  ];

  # Home Manager
  users.users.jbo = {
    name = "jbo";
    home = "/Users/jbo";
  };

  home-manager.users.jbo = { pkgs, ... }: {
    home.stateVersion = "22.11";

    programs.zsh = {
      enable = true;

      shellAliases = {
        cdg = "cd $HOME/src";
        g = "git";
        l = "ls -tlr --color=auto";
        la = "ls -tlra --color=auto";
        n = "nvim";
      };

      initExtra = ''
        # Only bind ctrl-r to atuin
        # TODO: rework once we get atuin v13
        # Should be simplified to: eval "$(atuin init zsh --disable-up-arrow)"
        export ATUIN_NOBIND="true"
        eval "$(atuin init zsh)"
        bindkey '^r' _atuin_search_widget

        # Bind keyboard control characters to useful functions
        # TODO: Understand why using zsh from nix breaks home / end / del
        bindkey '^[[1~' beginning-of-line               # Home / Fn Left-Arrow
        bindkey '^[[5~' beginning-of-buffer-or-history  # Page-up / Fn Up-Arrow
        bindkey '^[[4~' end-of-line                     # End / Fn Right-Arrow
        bindkey '^[[6~' end-of-buffer-or-history        # Page-down / Fn Down-Arrow
        bindkey '^[[3~' delete-char                     # Del / Fn delete
        bindkey '^[[1;3D' backward-word                 # Option Left-Arrow
        bindkey '^[[1;3C' forward-word                  # Option Right-Arrow
      '';

      sessionVariables = {
        CLICOLOR = "1";
      };
    };

    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal.family = "SauceCodePro Nerd Font";
          size = 14;
        };

        # Vendored from https://github.com/challenger-deep-theme/alacritty/
        colors = {
          # Default colors
          primary = {
            background = "0x1b182c";
            foreground = "0xcbe3e7";
          };

          # Normal colors
          normal = {
            black = "0x100e23";
            red = "0xff8080";
            green = "0x95ffa4";
            yellow = "0xffe9aa";
            blue = "0x91ddff";
            magenta = "0xc991e1";
            cyan = "0xaaffe4";
            white = "0xcbe3e7";
          };

          # Bright colors
          bright = {
            black = "0x565575";
            red = "0xff5458";
            green = "0x62d196";
            yellow = "0xffb378";
            blue = "0x65b2ff";
            magenta = "0x906cff";
            cyan = "0x63f2f1";
            white = "0xa6b3cc";
          };
        };
      };
    };

    programs.starship = {
      enable = true;
    };

    programs.neovim = {
      enable = true;

      defaultEditor = true;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      extraConfig = ''
        " Configure vim color scheme
        set termguicolors
        colorscheme challenger_deep

        " Configure no backups or swap files
        set nobackup noswapfile

        " Text width to 80
        set tw=80

        " 2 space tabs
        set sw=2 ts=2 expandtab

        " Disable infurating yaml behavior
        autocmd FileType yaml,yaml.ansible setlocal indentkeys-=0#

        " Show whitespace characters
        set list listchars=trail:~,tab:>-,nbsp:␣
        hi Whitespace ctermbg=red guibg=red

        " Remaps
        nnoremap \w     <cmd>bd<cr>
        nnoremap <C-H>  <cmd>tabp<cr>
        nnoremap <C-L>  <cmd>tabn<cr>

        nnoremap <C-P>  <cmd>lua require('telescope.builtin').find_files()<cr>

        " Setup Plugins
        lua require'nvim-lastplace'.setup{}
      '';
      plugins = with pkgs.vimPlugins;
        let
        in [
          markdown-preview-nvim
          nvim-lastplace
          telescope-nvim
          vim-challenger-deep-theme
          vim-elixir
          vim-nix
          vim-prettier
        ];
    };

    programs.tmux = {
      enable = true;
      extraConfig = ''
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

        # Auto-rename panes
        set-option -g status-interval 2
        set-option -g automatic-rename on
        set-option -g automatic-rename-format '#{b:pane_current_path}'

      '' + builtins.readFile ./challenger-deep.tmuxtheme;
      terminal = "tmux-256color";
    };

    programs.atuin = {
      enable = true;
      enableZshIntegration = false;
    };

    programs.zoxide = {
      enable = true;
    };

    programs.git = {
      enable = true;
      lfs.enable = true;

      userName = "John Ott";
      userEmail = "john@johnott.us";

      aliases = {
        cp = "cherry-pick";
        cm = "commit -m";
        di = "diff";
        ds = "diff --staged";
        fc = "fzf-checkout";
        fo = "fzf-oneline";
        fwl = "push --force-with-lease";
        o = "log --oneline";
        poh = "push -u origin HEAD";
        pohfwl = "push -u origin HEAD --force-with-lease";
        ri = "rebase -i";
        rim = "rebase -i origin/master";
        rom = "rebase origin/master";
        rup = "remote update -p";
        rur = "!git remote update && git rebase -i origin/master";
        st = "status";
      };

      extraConfig = {
        init.defaultBranch = "main";
      };
    };

    programs.dircolors = {
      enable = true;
    };

    programs.direnv = {
      enable = true;
    };
  };
}
