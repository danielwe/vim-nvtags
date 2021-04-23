" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#after#pandoc#init_buffer()
  if !exists('b:nvtags_completers')
    return
  endif
  call add(b:nvtags_completers, s:completer_pandoc)
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
