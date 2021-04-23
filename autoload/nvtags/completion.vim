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
  let l:refdir = expand('%:p:h')
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  call filter(l:candidates, 'filereadable(v:val)')
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
  let l:pathstart = match(l:line, '\[\[\zs[^\[\]#|]\{-1,}|[^\]]\{-}$')
  let l:labelstart = match(l:line, '\[\[[^\[\]#|]\{-1,}|\zs[^\]]\{-}$')
  let self['path'] = l:line[l:pathstart:l:labelstart - 2]
  return l:labelstart
endfunction

function! s:completer_wikilabel.complete(base) dict abort
  let l:refdir = expand('%:p:h')
  let l:path = l:refdir . '/' . self['path']
  let l:candidates = [l:path] + expand(l:path . '.*', 0, 1)

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
  let l:refdir = expand('%:p:h')
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  call filter(l:candidates, 'filereadable(v:val)')
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
  let l:refdir = expand('%:p:h')
  let l:dirs = nvtags#search_paths()
  let l:candidates = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)

  call filter(l:candidates, 'filereadable(v:val)')
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

let s:completer_wikianchor = {}

function! s:completer_wikianchor.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  let l:pathstart = match(l:line, '\[\[\zs[^\[\]#|]\{-}#[[:ident:]\-]\{-}$')
  let l:anchorstart = match(l:line, '\[\[[^\[\]#|]\{-}#\zs[[:ident:]\-]\{-}$')
  let self['path'] = l:line[l:pathstart:l:anchorstart - 2]
  return l:anchorstart
endfunction

function! s:completer_wikianchor.complete(base) dict abort
  if self['path'] == ""
    let l:files = [expand('%')]
  else
    let l:refdir = expand('%:p:h')
    let l:path = l:refdir . '/' . self['path']
    let l:files = [l:path] + expand(l:path . '.*', 0, 1)
  endif

  call filter(l:files, 'filereadable(v:val)')
  let l:candidates = []
  for l:file in l:files
    call extend(l:candidates, s:completer_anchor_entries(l:file))
  endfor
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

let s:completer_mdanchor = {}

function! s:completer_mdanchor.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  let l:urlpat = percent#encoded_pattern()
  let l:pathstart = match(
        \ l:line, '\[[^\]]\{-}\](\zs' . l:urlpat . '\{-}#[[:ident:]\-]\{-}$'
        \)
  let l:anchorstart = match(
        \ l:line, '\[[^\]]\{-}\](' . l:urlpat . '\{-}#\zs[[:ident:]\-]\{-}$'
        \)
  let self['path'] = percent#decode(l:line[l:pathstart:l:anchorstart - 2])
  return l:anchorstart
endfunction

function! s:completer_mdanchor.complete(base) dict abort
  if self['path'] == ""
    let l:path = expand('%')
  else
    let l:refdir = expand('%:p:h')
    let l:path = l:refdir . '/' . self['path']
  endif
  if !filereadable(l:path)
    return []
  endif

  let l:candidates = s:completer_anchor_entries(l:path)
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:completer_anchor_entries(path) abort
  let l:entries = []
  for [l:header, l:anchor] in s:get_anchors(a:path)
    call add(l:entries, {'abbr': l:header, 'word': l:anchor, 'menu': '[anchor]'})
  endfor
  return l:entries
endfunction

let s:atx_pattern = '\v^#{1,6} '

function s:get_anchors(file) abort
  let l:anchors = []
  let l:counts = {}
  let l:preblock = 0
  for l:line in readfile(a:file)
    " Ignore fenced code blocks
    if l:line =~# '^\s*```'
      let l:preblock += 1
    endif
    if l:preblock % 2 | continue | endif
    
    if l:line =~# s:atx_pattern 
      let l:header = trim(substitute(l:line, s:atx_pattern, '', ''))
      let l:anchor = s:toanchor(l:header)
      if exists('l:counts["' . l:anchor . '"]')
        let l:anchor .= "-" . l:counts[l:anchor]
        let l:counts[l:anchor] += 1
      else
        let l:counts[l:anchor] = 1
      end
      call add(l:anchors, [l:header, l:anchor])
    endif
  endfor
  return l:anchors
endfunction

function s:toanchor(header) abort
  let l:anchor = tolower(a:header)
  let l:anchor = substitute(l:anchor, '\v[^[:ident:]\- ]+', '', 'g')
  let l:anchor = substitute(l:anchor, ' ', '-', 'g')
  return l:anchor
endfunction

function! nvtags#completion#init_buffer()
  let b:nvtags_completers = map(
        \ filter(items(s:), 'v:val[0] =~# "^completer_"'), 'v:val[1]'
        \)
  setlocal omnifunc=nvtags#completion#omnicomplete
endfunction
