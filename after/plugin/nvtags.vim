" notational-vim-fzf interoperability
if exists(':NV') == 2
  command! -bang -nargs=? NT execute 'NV<bang>' g:nvtags_tagline_pattern
        \ | if empty(<q-bang>) | call feedkeys(<q-args>) | endif
  command! NTHere execute 'NT' NVTagsGetQuery(getline('.'))
endif
