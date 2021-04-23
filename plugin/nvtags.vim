" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

" dependencies
if !executable('rg')
    echoerr '`rg` is not installed. See https://github.com/BurntSushi/ripgrep for installation instructions.'
    finish
endif

if !exists('g:percent_loaded') || g:percent_loaded == 0
  echoerr '`vim-percent` is not installed and loaded. Available at https://github.com/danielwe/vim-percent.'
  finish
endif

let g:nvtags_loaded = 1

let g:nvtags_defaults = {
      \ 'tagline_prefix': '',
      \ 'tag_pattern': '#\w{2,}(/|\w)*',
      \ 'uid_pattern': '\v(^\d{12,}|\d{12,}$)',
      \ 'globs': ['*.md'],
      \ 'search_paths': [],
      \ 'link_type': 'wiki',
      \ 'completion_glob': '**/*.*',
      \ 'label_scan_num_lines': 10,
      \}

" commands for creating dynamic tag-based indexes
command! -range -bar NVTagsClear execute "normal! mt"
      \ | execute "<line1>normal! A\<Space>\<Esc>d}`t"

command! -bang -nargs=? -range -count NVTags
    \ if !empty('<bang>') | <line1>NVTagsClear | endif |
    \ call fzf#run({
    \ 'sink*': {
    \  greplines -> nvtags#append_greplinks(
    \   <line1>, greplines, <count> - <line1>, nvtags#get('link_type'),
    \  )
    \ },
    \ 'options': ['--exact', '--no-sort', '--filter=<args>'],
    \ 'source': join([
    \  'command',
    \  'rg',
    \  '--max-count 1',
    \  '--follow',
    \  '--color never',
    \  '--no-messages',
    \  '--no-heading',
    \  '--with-filename',
    \  nvtags#get('sort_arg'),
    \  join(map(copy(nvtags#get('globs')), '"--glob " . shellescape(v:val)')),
    \  shellescape(nvtags#patterns#tagline()),
    \  join(map(nvtags#search_paths(), 'shellescape(v:val)')),
    \  '2>/dev/null',
    \ ]),
    \})
command! -bang -range NVTagsHere
      \ execute '<line1>NVTags<bang>' nvtags#query(getline('.'))

command! -bang NVTagsAll
      \ execute 'global/' . nvtags#patterns#queryline() . '/NVTagsHere<bang>'
      \ | normal! ``
command! NVTagsClearAll
      \ execute 'global/' . nvtags#patterns#queryline() . '/NVTagsClear' | normal! ``

augroup mdcomplete
  autocmd!
  autocmd! FileType markdown,pandoc setlocal omnifunc=nvtags#completion#omnicomplete
augroup END

call nvtags#completion#init()
