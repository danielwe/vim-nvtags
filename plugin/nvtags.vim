" Dependencies
if !executable('rg')
    echoerr '`rg` is not installed. See https://github.com/BurntSushi/ripgrep for installation instructions.'
    finish
endif

if !exists('g:percent_loaded') || g:percent_loaded == 0
  echoerr '`vim-percent` is not installed and loaded. Available at https://github.com/danielwe/vim-percent.'
  finish
endif

" Settings
function! s:TaglinePattern(prefix, tags) abort
  if !empty(a:prefix)
    let l:tagline_prefix = '\s*' . g:nvtags_tagline_prefix . '\s*:\s*'
  else
    let l:tagline_prefix =  '(?:.*:\s*)?'
  endif
  return '^' . l:tagline_prefix . '(?:' . a:tags . '(?:$|\s+))+$'
endfunction

function! s:QuerylinePattern(prefix, tags) abort
  let queryline = '%(.*:\s*)?\zs\d*\s*%(%(''|\^|!\^?)?'
        \ . s:RustToVimRegex(a:tags)
        \ . '\$?\ze%($|\s+))+$'
  if !empty(a:prefix)
    let tagline = s:TaglinePattern(a:prefix, a:tags)
    let queryline = '%(' . s:RustToVimRegex(l:tagline) . ')@!' . l:queryline
  endif
  return '\v^' . l:queryline
endfunction

" This clearly covers only a tiny part of two syntaxes that are incompatible anyway.
" Produces very magic (\v) vim regexes.
let s:rust_to_vim_regex = {
      \ '\v\(\?:': '%(',
      \ '\v\C\\w': '\\i',
      \ '\v\C\\W': '%(\\i@!.)',
      \ '\v\/': '\\/',
      \ }

function! s:RustToVimRegex(regex) abort
  let l:regex = a:regex
  for [pattern, substitution] in items(s:rust_to_vim_regex)
    let regex = substitute(l:regex, pattern, substitution, 'g')
  endfor
  return l:regex
endfunction

let s:prefix = get(g:, 'nvtags_tagline_prefix', '')
let s:tags = get(g:, 'nvtags_pattern', '#\w{2,}(/|\w)*')
let s:uid_pattern = get(g:, 'nvtags_uid_pattern', '\v(^\d{12,}|\d{12,}$)')
let g:nvtags_tagline_pattern = s:TaglinePattern(s:prefix, s:tags)
let g:nvtags_queryline_pattern = s:QuerylinePattern(s:prefix, s:tags)

" Create dynamic tag-based indexes
function! NVTagsATXFirstH1(buflines) abort
  let l:index = match(a:buflines, '\v^#\ ')
  if l:index >= 0
    return trim(a:buflines[l:index][2:])
  endif
  return ""
endfunction

function! NVTagsTrimUID(title) abort
  return trim(substitute(a:title, s:uid_pattern, '', ''))
endfunction

function s:LinkLabel(path) abort
  let l:label = NVTagsATXFirstH1(readfile(a:path, '', 1))
  if l:label == ""
    let l:label = fnamemodify(a:path, ':t:r')
  endif
  return NVTagsTrimUID(l:label)
endfunction

function! s:WikiLink(path, label="") abort
  let l:path = fnamemodify(a:path, ':r')
  let l:link = '[[' . l:path
  if a:label != "" && a:label !=# l:path
    let l:link .= '|' . a:label
  endif
  let l:link .= ']]'
  return l:link
endfunction

function! s:MarkdownLink(path, label, title="") abort
  let l:link = '[' . a:label . '](' . percent#encode(a:path)
  if a:title != ""
    let l:link .= ' "' . a:title . '"'
  endif
  let l:link .= ')'
  return l:link
endfunction

function! s:LinkFromGrep(grepline, refdir, type) abort
  let l:parts = split(a:grepline, ':')
  let l:path = l:parts[0]
  let l:label = s:LinkLabel(l:path)
  let l:relpath = s:Relpath(l:path, a:refdir)
  if tolower(a:type) == "wiki"
    return s:WikiLink(l:relpath, l:label)
  endif
  if tolower(a:type) == "markdown"
    let l:title = trim(l:parts[-1])
    return s:MarkdownLink(l:relpath, l:label, l:title)
  endif
  echoerr "unknown link type: " . a:type
endfunction

function! s:Relpath(path, refdir="") abort
  if a:refdir == ""
    return a:path
  endif
  python3 import os, vim
  return py3eval('os.path.relpath(vim.eval("a:path"), vim.eval("a:refdir"))')
endfunction

function! s:AppendLinks(lnum, greplines, n, type) abort
  if a:n > 0
    let l:n = a:n
  else
    let l:n = -1
  endif
  if len(a:greplines) > 0
    let l:refdir = expand('%:p:h')
    let l:links = map(
          \ a:greplines[:l:n], '"* " . s:LinkFromGrep(v:val, l:refdir, a:type)'
          \)
    call append(a:lnum, ['  '] + l:links)
  endif
endfunction

function! NVTagsGetQuery(queryline) abort
  return trim(split(a:queryline, ':')[-1])
endfunction

function! NVTagsSearchPaths() abort
  let l:dirs = map(copy(get(g:, 'nvtags_search_paths', [])), 'expand(v:val)')
  let l:curdir = expand(getcwd())
  if match(l:dirs, l:curdir) == -1
    let l:dirs = [l:curdir] + l:dirs
  endif
  return l:dirs
endfunction

command! -range -bar NVTagsClear execute "normal! mt"
      \ | execute "<line1>normal! A\<Space>\<Esc>d}`t"

command! -bang -nargs=? -range -count NVTags
      \   if !empty('<bang>')
      \ |   <line1>NVTagsClear
      \ | endif
      \ | call fzf#run({
      \     'sink*': {
      \       greplines -> s:AppendLinks(
      \         <line1>,
      \         greplines,
      \         <count> - <line1>,
      \         get(g:, 'nvtags_link_type', 'wiki'),
      \       )
      \     },
      \     'options': ['--exact', '--no-sort', '--filter=<args>'],
      \     'source': join([
      \       'command',
      \       'rg',
      \       '--max-count 1',
      \       '--follow',
      \       '--color never',
      \       '--no-messages',
      \       '--no-heading',
      \       '--with-filename',
      \       '--sortr modified',
      \       join(
      \         map(
      \           copy(get(g:, 'nvtags_globs', ['*.md'])),
      \           '"--glob " . shellescape(v:val)',
      \         )
      \       ),
      \       shellescape(g:nvtags_tagline_pattern),
      \       join(map(NVTagsSearchPaths(), 'shellescape(v:val)')),
      \       '2>/dev/null',
      \     ]),
      \   })
command! -bang -range NVTagsHere
      \ execute '<line1>NVTags<bang>' NVTagsGetQuery(getline('.'))

command! -bang NVTagsAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsHere<bang>' | normal! ``
command! NVTagsClearAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsClear' | normal! ``

" Markdown link completion, inspired by wiki.vim
function! NVTagsOmnicomplete(findstart, base) abort
  if a:findstart
    return s:NVTagsFindstart(a:base)
  endif
  return s:NVTagsComplete(a:base)
endfunction

function! s:NVTagsFindstart(base) abort
  if exists('s:completer')
    unlet s:completer
  endif
  let l:cnum = -1
  for l:completer in g:nvtags_completers
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

function s:NVTagsComplete(base) abort
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
  let l:dirs = NVTagsSearchPaths()
  let l:candidates = globpath(
        \ join(l:dirs, ','), get(g:, 'nvtags_completion_glob', '**/*.md'), 0, 1,
        \ )

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:WikiEntry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:WikiEntry(path, refdir) abort
  let l:label = s:LinkLabel(a:path)
  let l:relpath = s:Relpath(a:path, a:refdir)
  let l:link = s:WikiLink(l:relpath)
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
  call map(l:candidates, 's:WikiLabelEntry(v:val)')
  call filter(l:candidates, 'match(v:val.word, a:base) >= 0')

  return l:candidates
endfunction

function! s:WikiLabelEntry(path) abort
  return {'word': s:LinkLabel(a:path), 'menu': '[wikilabel]'}
endfunction

let s:completer_mdurl = {}

function! s:completer_mdurl.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\[[^\]]\{-}\](\zs[^)]\{-}$')
endfunction

function! s:completer_mdurl.complete(base) dict abort
  let l:dirs = NVTagsSearchPaths()
  let l:candidates = globpath(
        \ join(l:dirs, ','), get(g:, 'nvtags_completion_glob', '**/*.md'), 0, 1,
        \ )

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:MDURLEntry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:MDURLEntry(path, refdir) abort
  let l:label = s:LinkLabel(a:path)
  let l:relpath = s:Relpath(a:path, a:refdir)
  return {'abbr': l:label, 'word': percent#encode(l:relpath), 'menu': '[mdurl]'}
endfunction

let s:completer_mdlabel = {}

function! s:completer_mdlabel.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\(^\|[^\[]\)\[\zs[^\[)]\{-}$')
endfunction

function! s:completer_mdlabel.complete(base) dict abort
  let l:dirs = NVTagsSearchPaths()
  let l:candidates = globpath(
        \ join(l:dirs, ','), get(g:, 'nvtags_completion_glob', '**/*.md'), 0, 1,
        \)

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:MDLabelEntry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:MDLabelEntry(path, refdir) abort
  let l:label = s:LinkLabel(a:path)
  let l:relpath = s:Relpath(a:path, a:refdir)
  let l:link = s:MarkdownLink(l:relpath, l:label)
  return {'abbr': l:label, 'word': l:link[1:-2], 'menu': '[mdlabel]'}
endfunction

let g:nvtags_completers = map(
      \ filter(items(s:), 'v:val[0] =~# ''^completer_'''), 'v:val[1]'
      \)

augroup mdcomplete
  autocmd!
  autocmd! FileType markdown,pandoc setlocal omnifunc=NVTagsOmnicomplete
augroup END
