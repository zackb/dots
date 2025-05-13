syntax on
let mapleader=" "
set tabstop=4
set number
set expandtab
set shiftwidth=4
set foldmethod=marker
set ai
set incsearch
set wildmenu
set ruler
highlight Normal guibg=white

noremap <leader>fr :browse oldfiles<cr>

"color icansee
color desert

"Reselect visual block after indent/outdent
"vnoremap < <gv
"vnoremap > >gv

"Use jk as <Esc> alternative
inoremap jk <Esc>

set mmp=5000
