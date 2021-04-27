" Miscellaneous document tagging and wiki linking functionality
"
" Maintainer: Daniel Wennberg
"

function! nvtags#link#wiki(path, label="", title="") abort
  let l:path = fnamemodify(a:path, ':r')
  let l:link = '[[' . l:path
  if a:label != "" && a:label !=# l:path
    let l:link .= '|' . a:label
  endif
  let l:link .= ']]'
  return l:link
endfunction

function! nvtags#link#markdown(path, label, title="") abort
  let l:link = '[' . a:label . '](' . percent#encode(a:path)
  if a:title != ""
    let l:link .= ' "' . a:title . '"'
  endif
  let l:link .= ')'
  return l:link
endfunction

function! nvtags#link#relpath(path, refdir="") abort
  if a:refdir == ""
    return a:path
  endif
  python3 import os, vim
  return py3eval('os.path.relpath(vim.eval("a:path"), vim.eval("a:refdir"))')
endfunction

function! nvtags#link#label(path) abort
  let l:label = nvtags#link#firstATXH1(
        \ readfile(a:path, '', nvtags#get('label_scan_num_lines'))
        \)
  if l:label == ""
    let l:label = fnamemodify(a:path, ':t:r')
  endif
  return nvtags#link#trimUID(l:label)
endfunction

function! nvtags#link#firstATXH1(buflines) abort
  let l:index = match(a:buflines, '\v^#\ ')
  if l:index >= 0
    return trim(a:buflines[l:index][2:])
  endif
  return ""
endfunction

function! nvtags#link#trimUID(label) abort
  return trim(substitute(a:label, nvtags#get('uid_pattern'), '', ''))
endfunction
