" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#triggers#ycm(filetype="")
  let l:triggers = [
        \ '[[',
        \ 're!\[.*?\]\(',
        \ 're!\[\[[^\[\]\|]*?#',
        \ 're!\[.*?\]\(' . percent#encoded_pattern() .'*?#',
        \ 're!\[\[[^\[\]]+?\|',
        \]
  if a:filetype ==? 'pandoc' && exists('g:nvtags_pandoc_loaded') && g:nvtags_pandoc_loaded
    call add(l:triggers, '@')
  endif
  return l:triggers
endfunction
