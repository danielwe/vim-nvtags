" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#patterns#tagline() abort
  let l:prefix = nvtags#get('tagline_prefix')
  if !empty(l:prefix)
    let l:prefix = '\s*' . l:prefix . '\s*:\s*'
  else
    let l:prefix =  '(?:.*:\s*)?'
  endif
  return '^' . l:prefix . '(?:' . nvtags#get('tag_pattern') . '(?:$|\s+))+$'
endfunction

function! nvtags#patterns#queryline() abort
  let l:pattern =
        \ '%(.*:\s*)?\zs\d*\s*%(%(''|\^|!\^?)?'
        \ . s:rust_to_vim(nvtags#get('tag_pattern'))
        \ . '\$?\ze%($|\s+))+$'
  let l:tagline_prefix = nvtags#get('tagline_prefix')
  if !empty(l:tagline_prefix)
    let l:tagline_pattern = nvtags#patterns#tagline()
    let l:pattern = '%(' . s:rust_to_vim(l:tagline_pattern) . ')@!' . l:pattern
  endif
  return '\v^' . l:pattern
endfunction

" Translate Rust regex patterns to vim regex patterns. This obviously only covers a tiny
" part of two incompatible syntaxes. Produces very magic (\v) vim patterns.
let s:rust_to_vim_patterns = {
      \ '\v\(\?:': '%(',
      \ '\v\C\\w': '\\i',
      \ '\v\C\\W': '%(\\i@!.)',
      \ '\v\/': '\\/',
      \}

function! s:rust_to_vim(pattern) abort
  let l:pattern = a:pattern
  for [rust_pattern, vim_pattern] in items(s:rust_to_vim_patterns)
    let l:pattern = substitute(l:pattern, rust_pattern, vim_pattern, 'g')
  endfor
  return l:pattern
endfunction
