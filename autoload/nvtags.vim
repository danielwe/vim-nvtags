" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#get(var) abort
  return get(g:, 'nvtags_' . a:var, g:nvtags_defaults[a:var])
endfunction

function! nvtags#search_paths() abort
  let l:dirs = map(copy(nvtags#get('search_paths')), 'expand(v:val)')
  let l:curdir = expand(getcwd())
  if match(l:dirs, l:curdir) == -1
    let l:dirs = [l:curdir] + l:dirs
  endif
  return l:dirs
endfunction

function! nvtags#query(queryline) abort
  return trim(split(a:queryline, ':')[-1])
endfunction

function! nvtags#append_greplinks(lnum, greplines, nlines, type) abort
  if a:nlines > 0
    let l:greplines = a:greplines[:a:nlines]
  else
    let l:greplines = a:greplines
  endif
  if len(l:greplines) > 0
    let l:refdir = expand('%:p:h')
    let l:links = map(l:greplines, '"* " . nvtags#greplink(v:val, l:refdir, a:type)')
    call append(a:lnum, ['  '] + l:links)
  endif
endfunction

function! nvtags#greplink(grepline, refdir, type) abort
  let l:parts = split(a:grepline, ':')
  let l:path = l:parts[0]
  let l:label = nvtags#link#label(l:path)
  let l:title = trim(l:parts[-1])
  let l:relpath = nvtags#link#relpath(l:path, a:refdir)
  try
    let l:LinkFn = function('nvtags#link#' . a:type)
  catch
    echoerr "unknown link type: " . a:type
  endtry
  return l:LinkFn(l:relpath, l:label, l:title)
endfunction
