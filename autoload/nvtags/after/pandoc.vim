" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#after#pandoc#init()
  if !exists('g:nvtags_completers')
    let g:nvtags_completers = []
  endif
  call add(g:nvtags_completers, s:completer_pandoc)
  let g:nvtags_pandoc_loaded = 1
endfunction

let s:completer_pandoc = {}

function! s:completer_pandoc.findstart(base) dict abort
  try
    return pandoc#completion#Complete(1, a:base)
  catch
    return -1
  endtry
endfunction

function! s:completer_pandoc.complete(base) dict abort
  try
    return pandoc#completion#Complete(0, a:base)
  catch
    return []
  endtry
endfunction
