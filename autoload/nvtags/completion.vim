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
  let l:line = getline('.')[:col('.') - 2]
  let l:cnum = -1
  for l:completer in b:nvtags_completers
    let l:this_cnum = l:completer.findstart(l:line)
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

" link completion
function! s:candidates() abort
  let l:dirs = nvtags#search_paths()
  let l:files = globpath(join(l:dirs, ','), nvtags#get('completion_glob'), 0, 1)
  call filter(l:files, 'filereadable(v:val)')
  return l:files
endfunction

function! s:link_parts(path, refdir) abort
  return [nvtags#link#relpath(a:path, a:refdir), nvtags#link#label(a:path)]
endfunction

let s:completer_wiki = {'startpattern': '\[\[\zs[^\[\]\|#]\{-}$'}

function! s:completer_wiki.findstart(line) dict abort
  return match(a:line, self['startpattern'])
endfunction

function! s:completer_wiki.complete(base) dict abort
  let l:refdir = expand('%:p:h')
  let l:candidates = s:candidates()
  call map(l:candidates, 's:link_parts(v:val, l:refdir)')
  call map(l:candidates, 'self.entry(v:val[0], v:val[1])')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')
  return l:candidates
endfunction

function! s:completer_wiki.entry(relpath, label) dict abort
  return {'abbr': a:label, 'word': nvtags#link#wiki(a:relpath)[2:-3], 'menu': '[wiki]'}
endfunction

let s:completer_mdurl = deepcopy(s:completer_wiki)
let s:completer_mdurl['startpattern'] = '\[.\{-}\](\zs[^)]\{-}$'

function! s:completer_mdurl.entry(relpath, label) dict abort
  return {'abbr': a:label, 'word': percent#encode(a:relpath), 'menu': '[mdurl]'}
endfunction

let s:completer_mdlabel = deepcopy(s:completer_mdurl)
let s:completer_mdlabel['startpattern'] = '\(^\|[^\[]\)\[\zs[^\[)]\{-}$'

function! s:completer_mdlabel.entry(relpath, label) dict abort
  let l:link = nvtags#link#markdown(a:relpath, a:label)
  return {'abbr': a:label, 'word': l:link[1:-2], 'menu': '[mdlabel]'}
endfunction

" anchor completion
function! s:path_candidates(path) abort
  let l:refdir = expand('%:p:h')
  if a:path == ""
    let l:files = [expand('%')]
  else
    let l:path = l:refdir . '/' . a:path
    let l:files = [l:path] + expand(l:path . '.*', 0, 1)
  endif
  call filter(l:files, 'filereadable(v:val)')
  return l:files
endfunction

let s:_atx_pattern = '\v^#{1,6} '

function s:get_headers(file) abort
  let l:headers = []
  let l:counts = {}
  let l:preblock = 0
  for l:line in readfile(a:file)
    " Ignore fenced code blocks
    if l:line =~# '^\s*```'
      let l:preblock += 1
    endif
    if l:preblock % 2 | continue | endif

    if l:line =~# s:_atx_pattern 
      let l:raw_header = trim(l:line)
      let l:header = trim(substitute(l:raw_header, s:_atx_pattern, '', ''))
      if exists('l:counts["' . l:header . '"]')
        let l:counts[l:header] += 1
      else
        let l:counts[l:header] = 0
      end
      call add(l:headers, [l:header, l:raw_header, l:counts[header]])
    endif
  endfor
  return l:headers
endfunction

let s:completer_wikianchor = {
     \ 'pathstartpattern': '\[\[\zs[^\[\]#|]\{-}#[^\[\]|]\{-}$',
     \ 'basestartpattern': '\[\[[^\[\]#|]\{-}#\zs[^\[\]|]\{-}$',
     \}

function! s:completer_wikianchor.findstart_core(line) dict abort
  let l:pathstart = match(a:line, self['pathstartpattern'])
  let l:basestart = match(a:line, self['basestartpattern'])
  let self['path'] = a:line[l:pathstart:l:basestart - 2]
  return l:basestart
endfunction

function! s:completer_wikianchor.findstart(line) dict abort
  return self.findstart_core(a:line)
endfunction

function! s:completer_wikianchor.complete(base) dict abort
  let l:files = s:path_candidates(self['path'])

  let l:candidates = []
  for l:file in l:files
    call extend(l:candidates, s:get_headers(l:file))
  endfor
  call map(l:candidates, 'self.entry(v:val[0], v:val[1], v:val[2])')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')
  return l:candidates
endfunction

function! s:completer_wikianchor.entry(header, raw_header, count) dict abort
  if a:count > 0
    return {'abbr': '', 'word': '', 'menu': ''}
  endif
  return {'abbr': a:raw_header, 'word': a:header, 'menu': '[anchor]'}
endfunction

let s:_url_pattern = percent#encoded_pattern()
let s:completer_mdanchor = deepcopy(s:completer_wikianchor)
let s:completer_mdanchor['pathstartpattern'] =
      \ '\[.\{-}\](\zs' . s:_url_pattern . '\{-}#[[:ident:]-]\{-}$'
let s:completer_mdanchor['basestartpattern'] =
      \ '\[.\{-}\](' . s:_url_pattern . '\{-}#\zs[[:ident:]-]\{-}$'

function! s:completer_mdanchor.findstart(line) dict abort
  let l:basestart = self.findstart_core(a:line)
  let self['path'] = percent#decode(self['path'])
  return l:basestart
endfunction

function! s:completer_mdanchor.entry(header, raw_header, count) dict abort
  let l:anchor = s:mdanchor(a:header, a:count)
  return {'abbr': a:raw_header, 'word': l:anchor, 'menu': '[anchor]'}
endfunction

function s:mdanchor(header, count) abort
  let l:anchor = tolower(a:header)
  let l:anchor = substitute(l:anchor, '\v[^[:ident:]- ]+', '', 'g')
  let l:anchor = substitute(l:anchor, ' ', '-', 'g')
  if a:count > 0
    let l:anchor .= "-" . a:count
  endif
  return l:anchor
endfunction

" label completion
let s:completer_wikilabel = {
      \ 'pathstartpattern': '\[\[\zs[^\[\]|]\{-1,}|[^\]]\{-}$',
      \ 'basestartpattern': '\[\[[^\[\]|]\{-1,}|\zs[^\]]\{-}$',
      \}

function! s:completer_wikilabel.findstart(line) dict abort
  let l:pathstart = match(a:line, self['pathstartpattern'])
  let l:basestart = match(a:line, self['basestartpattern'])
  let self['path'] = a:line[l:pathstart:l:basestart - 2]
  if self['path'] =~# '#'
    let l:anchstart = s:completer_wikianchor.findstart(a:line[:l:basestart - 2])
    let self['anchpath'] = s:completer_wikianchor['path']
    let self['anchor'] = a:line[l:anchstart:l:basestart - 2]
  endif
  return l:basestart
endfunction

function! s:completer_wikilabel.complete(base) dict abort
  let l:candidates = s:path_candidates(self['path'])
  call map(l:candidates, 's:completer_wikilabel.entry(v:val)')

  if self['path'] =~# '#'
    let l:files = s:path_candidates(self['anchpath'])
    let l:anchcandidates = []
    for l:file in l:files
      call extend(l:anchcandidates, s:get_headers(l:file))
    endfor
    call filter(l:anchcandidates, 'v:val[0] == self["anchor"]')
    call map(l:anchcandidates, 'self.anchentry(v:val[0])')
    call extend(l:candidates, l:anchcandidates)
  endif

  call filter(l:candidates, 'match(v:val.word, a:base) >= 0')
  return l:candidates
endfunction

function! s:completer_wikilabel.entry(path) dict abort
  return {'word': nvtags#link#label(a:path), 'menu': '[wikilabel]'}
endfunction

function! s:completer_wikilabel.anchentry(header) dict abort
  return {'word': a:header, 'menu': '[wikilabel]'}
endfunction

function! nvtags#completion#init_buffer()
  let b:nvtags_completers = map(
        \ filter(items(s:), 'v:val[0] =~# "^completer_"'), 'v:val[1]'
        \)
  setlocal omnifunc=nvtags#completion#omnicomplete
endfunction
