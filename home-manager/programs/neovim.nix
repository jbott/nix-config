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

    extraLuaConfig = ''
      -- Enable built in features
      vim.lsp.inlay_hint.enable()

      -- Setup Plugins
      require('lspconfig').eslint.setup{}
      require('nvim-lastplace').setup{}
      require('typescript-tools').setup {}

      -- Global mappings.
      -- See `:help vim.diagnostic.*` for documentation on any of the below functions
      vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
      vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

      -- Show line diagnostics automatically in hover window
      vim.o.updatetime = 250
      vim.cmd [[autocmd CursorHold,CursorHoldI * lua vim.diagnostic.open_float(nil, {focus=false})]]

      -- Use LspAttach autocommand to only map the following keys
      -- after the language server attaches to the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(ev)
          -- Enable completion triggered by <c-x><c-o>
          vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

          -- Buffer local mappings.
          -- See `:help vim.lsp.*` for documentation on any of the below functions
          local opts = { buffer = ev.buf }
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
          vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
          vim.keymap.set('n', '<space>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, opts)
          vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
          vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', '<space>f', function()
            vim.lsp.buf.format { async = true }
          end, opts)
        end,
      })

      -- Configure rustaceanvim
      vim.g.rustaceanvim = {
        inlay_hints = {
          highlight = "NonText",
        },
        tools = {
          hover_actions = {
            auto_focus = true,
          },
        },
      }
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-lastplace
      nvim-lspconfig
      plenary-nvim
      rustaceanvim
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
