" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#after#nv#backlinks_pattern() abort
  let l:wikipattern = '\[\[[^\[\]]*' . expand("%:t:r") . '.*?\]\]'
  let l:mdpattern = '\[.*?\]\(('
        \ . percent#encoded_pattern()
        \ . '*/)?'
        \ . s:escape_rust_pattern(percent#encode(expand("%:t")))
        \ . '.*?\)'
  return '(' . l:wikipattern . '|' . l:mdpattern . ')'
endfunction

function! nvtags#after#nv#mentions_pattern() abort
  return s:escape_rust_pattern(nvtags#link#label(expand('%')))
endfunction

function! s:escape_rust_pattern(str) abort
  return escape(a:str, '\.+*?()|[]{}^$')
endfunction
