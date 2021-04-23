" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

if !exists('g:nvtags_loaded') || g:nvtags_loaded == 0
  finish
endif

" notational-vim-fzf interoperability
if exists(':NV') == 2
  if !exists('g:nvtags_search_paths')
    let g:nvtags_search_paths = g:nv_search_paths
  end

  command! -bang -nargs=? NT execute 'NV<bang>' nvtags#patterns#tagline()
        \ | if empty(<q-bang>) | call feedkeys(<q-args>) | endif
  command! NTHere execute 'NT' nvtags#query(getline('.'))

  command! -bang NVBacklinks execute 'NV<bang>' nvtags#after#nv#backlinks_pattern()
  command! -bang NVMentions execute 'NV<bang>' nvtags#after#nv#mentions_pattern()
endif

if exists('g:pandoc#loaded') && g:pandoc#loaded && match(g:pandoc#modules#disabled, "completion") == -1
  call nvtags#after#pandoc#init()
endif
