{pkgs, ...}: let
  vim-challenger-deep-theme = pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "vim-challenger-deep-theme";
    src = pkgs.fetchFromGitHub {
      owner = "challenger-deep-theme";
      repo = "vim";
      rev = "e3d5b7d9711c7ebbf12c63c2345116985656da0d";
      hash = "sha256-2lIPun5OjaoHSG2BdnX9ztw3k9whVlBa9eB2vS8Htbg=";
    };
  };
in {
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

      " Do not auto-open markdown composer
      let g:markdown_composer_autostart = 0
    '';
    plugins = with pkgs.vimPlugins; let
    in [
      nvim-lastplace
      telescope-nvim
      vim-challenger-deep-theme
      vim-elixir
      vim-indent-object # NOTE: vii performs select at indent level
      vim-markdown-composer
      vim-nix
      vim-prettier
    ];
  };
}