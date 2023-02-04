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
    git
    neovim
    python311
    starship
    tmux
    watch
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
        l = "ls -tlr";
        la = "ls -tlra";
        g = "git";
        cdg = "cd $HOME/src";
      };

      initExtra = ''
        # Only bind ctrl-r to atuin
        # TODO: rework once we get atuin v13
        # Should be simplified to: eval "$(atuin init zsh --disable-up-arrow)"
        export ATUIN_NOBIND="true"
        eval "$(atuin init zsh)"
        bindkey '^r' _atuin_search_widget
      '';
    };

    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal.family = "SauceCodePro Nerd Font";
          size = 14;
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
      '';
      plugins = with pkgs.vimPlugins;
        let
        in [
          vim-nix
          vim-challenger-deep-theme
        ];
    };

    programs.tmux = {
      enable = true;
      extraConfig = ''
        set -g mouse on
      '';
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
    };
  };
}
