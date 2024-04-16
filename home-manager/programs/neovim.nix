{pkgs, ...}: let
  vim-challenger-deep-theme = pkgs.vimUtils.buildVimPlugin {
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

      " Configure the number column and display signs in the number column, and highlight it better
      set number signcolumn=number
      highlight LineNr term=bold cterm=NONE ctermfg=DarkGrey ctermbg=NONE gui=NONE guifg=DarkGrey guibg=NONE

      " Configure no backups or swap files
      set nobackup noswapfile

      " Text width to 100
      set tw=100

      " 2 space tabs
      set sw=2 ts=2 expandtab

      " Do not expand tabs on go files
      autocmd FileType go setlocal noexpandtab

      " Disable infurating yaml behavior
      autocmd FileType yaml,yaml.ansible setlocal indentkeys-=0#
      autocmd BufNewFile,BufRead *.yaml.j2 setlocal indentkeys-=0#

      " Show whitespace characters
      set list listchars=trail:~,tab:>-,nbsp:␣

      " Highlight whitespace characters at EOL
      match ExtraWhitespace /\s\+$/
      hi ExtraWhitespace ctermbg=red guibg=red

      " Remaps
      nnoremap <leader>w     <cmd>bd<cr>
      nnoremap <leader>f     <cmd>!just fmt<cr>
      nnoremap <C-H>  <cmd>tabp<cr>
      nnoremap <C-L>  <cmd>tabn<cr>

      nnoremap <C-P>  <cmd>lua require('telescope.builtin').find_files()<cr>
      nnoremap <C-F>  <cmd>lua require('telescope.builtin').live_grep()<cr>

      " Setup Plugins
      lua require'lspconfig'.eslint.setup{}
      lua require'nvim-lastplace'.setup{}
      lua require'typescript-tools'.setup {}

      " Do not auto-open markdown composer
      let g:markdown_composer_autostart = 0

      " vim-auto-mkdir plugin from
      " https://github.com/travisjeffery/vim-auto-mkdir/
      augroup vim-auto-mkdir
        autocmd!
        autocmd BufWritePre * call s:auto_mkdir(expand('<afile>:p:h'), v:cmdbang)
        function! s:auto_mkdir(dir, force)
          if !isdirectory(a:dir)
                \   && (a:force
                \       || input("'" . a:dir . "' does not exist. Create? [y/N]") =~? '^y\%[es]$')
            call mkdir(iconv(a:dir, &encoding, &termencoding), 'p')
          endif
        endfunction
      augroup END
    '';
    plugins = with pkgs.vimPlugins; let
    in [
      nvim-lastplace
      nvim-lspconfig
      plenary-nvim
      telescope-nvim
      typescript-tools-nvim
      vim-astro
      vim-challenger-deep-theme
      vim-elixir
      vim-fugitive
      vim-indent-object # NOTE: vii performs select at indent level
      vim-jinja
      vim-just
      vim-markdown-composer
      vim-nix
      vim-prettier
      vim-terraform
    ];
  };
}
