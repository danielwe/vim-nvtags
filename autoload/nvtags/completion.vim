" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

" link completion, inspired by wiki.vim
function! nvtags#completion#omnicomplete(findstart, base) abort
  if a:findstart
    return s:findstart(a:base)
  endif
  return s:complete(a:base)
endfunction

function! s:findstart(base) abort
  if exists('s:completer')
    unlet s:completer
  endif
  let l:cnum = -1
  for l:completer in b:nvtags_completers
    let l:this_cnum = l:completer.findstart(a:base)
    if l:this_cnum > l:cnum
      let s:completer = l:completer
      let l:cnum = l:this_cnum
    endif
  endfor

  if l:cnum < 0
    " -2  cancel silently and stay in completion mode.
    " -3  cancel silently and leave completion mode.
    return -3
  endif
  return l:cnum
endfunction

function s:complete(base) abort
  if !exists('s:completer')
    return []
  endif
  return s:completer.complete(a:base)
endfunction

let s:completer_wiki = {}

function! s:completer_wiki.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\[\[\zs[^\[\]\|#]\{-}$')
endfunction

function! s:completer_wiki.complete(base) dict abort
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:completer_wiki_entry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:completer_wiki_entry(path, refdir) abort
  let l:label = nvtags#link#label(a:path)
  let l:relpath = nvtags#link#relpath(a:path, a:refdir)
  let l:link = nvtags#link#wiki(l:relpath)
  return {'abbr': l:label, 'word': l:link[2:-3], 'menu': '[wiki]'}
endfunction

let s:completer_wikilabel = {}

function! s:completer_wikilabel.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\[\[[^\[\]#|]\{-1,}|\zs[^\[\]#]\{-}$')
endfunction

function! s:completer_wikilabel.complete(base) dict abort
  let l:refdir = expand('%:p:h')
  let l:line = getline('.')[:col('.') - 2]
  let l:rootstart = match(l:line, '\[\[\zs[^\[\]#|]\{-1,}|[^\[\]#]\{-}$')
  let l:rootend = len(l:line) - len(a:base) - 2
  let l:root = l:refdir . '/' . l:line[l:rootstart:l:rootend]
  let l:candidates = [l:root] + expand(l:root . '.*', 0, 1)

  call filter(l:candidates, 'filereadable(v:val)')
  call map(l:candidates, 's:completer_wikilabel_entry(v:val)')
  call filter(l:candidates, 'match(v:val.word, a:base) >= 0')

  return l:candidates
endfunction

function! s:completer_wikilabel_entry(path) abort
  return {'word': nvtags#link#label(a:path), 'menu': '[wikilabel]'}
endfunction

let s:completer_mdurl = {}

function! s:completer_mdurl.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\[[^\]]\{-}\](\zs[^)]\{-}$')
endfunction

function! s:completer_mdurl.complete(base) dict abort
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:completer_mdurl_entry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:completer_mdurl_entry(path, refdir) abort
  let l:label = nvtags#link#label(a:path)
  let l:relpath = nvtags#link#relpath(a:path, a:refdir)
  return {'abbr': l:label, 'word': percent#encode(l:relpath), 'menu': '[mdurl]'}
endfunction

let s:completer_mdlabel = {}

function! s:completer_mdlabel.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\(^\|[^\[]\)\[\zs[^\[)]\{-}$')
endfunction

function! s:completer_mdlabel.complete(base) dict abort
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:completer_mdlabel_entry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:completer_mdlabel_entry(path, refdir) abort
  let l:label = nvtags#link#label(a:path)
  let l:relpath = nvtags#link#relpath(a:path, a:refdir)
  let l:link = nvtags#link#markdown(l:relpath, l:label)
  return {'abbr': l:label, 'word': l:link[1:-2], 'menu': '[mdlabel]'}
endfunction

function! nvtags#completion#init_buffer()
  let b:nvtags_completers = map(
        \ filter(items(s:), 'v:val[0] =~# "^completer_"'), 'v:val[1]'
        \)
  setlocal omnifunc=nvtags#completion#omnicomplete
endfunction
