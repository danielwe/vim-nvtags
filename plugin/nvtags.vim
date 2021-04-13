" Dependencies
if !executable('rg')
    echoerr '`rg` is not installed. See https://github.com/BurntSushi/ripgrep for installation instructions.'
    finish
endif

if !exists('*PercentEncode')
  echoerr '`vim-percent` is not installed.'
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
function! NVTagsMarkdownTitle(buflines) abort
  let l:titleindex = match(a:buflines, '\v^#\ ')
  if l:titleindex >= 0
    return trim(a:buflines[l:titleindex][2:])
  endif
  return ""
endfunction

function! NVTagsTrimUID(title) abort
  return trim(substitute(a:title, s:uid_pattern, '', ''))
endfunction

function! s:MarkdownLink(path, refdir="", title="") abort
  let l:label = NVTagsTrimUID(NVTagsMarkdownTitle(readfile(a:path, '', 1)))
  if l:label == ""
    let l:label = fnamemodify(a:path, ':t:r')
  endif
  let l:path = a:refdir == "" ? a:path : s:Relpath(a:path, a:refdir)
  let l:link = '[' . l:label . '](' . PercentEncode(l:path)
  if a:title != ""
    let l:link .= ' "' . a:title . '"'
  endif
  let l:link .= ')'
  return [l:label, l:link]
endfunction

function! s:MarkdownLinkFromGrep(grepline, refdir) abort
  let l:parts = split(a:grepline, ':')
  return s:MarkdownLink(l:parts[0], a:refdir, trim(l:parts[-1]))
endfunction

function! s:Relpath(path, refdir) abort
  python3 import os, vim
  return py3eval('os.path.relpath(vim.eval("a:path"), vim.eval("a:refdir"))')
endfunction

function! s:AppendLinks(lnum, greplines, n) abort
  if a:n > 0
    let l:n = a:n
  else
    let l:n = -1
  endif
  if len(a:greplines) > 0
    let l:refdir = expand('%:p:h')
    call append(
          \ a:lnum,
          \ ['  ']
          \ + map(
          \   a:greplines[:l:n], '"* " . s:MarkdownLinkFromGrep(v:val, l:refdir)[1]'
          \ ),
          \ )
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
      \       greplines -> s:AppendLinks(<line1>, greplines, <count> - <line1>)
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
  for l:completer in g:nvtags_completers
    let l:cnum = l:completer.findstart(a:base)
    if l:cnum >= 0
      let s:completer = l:completer
      return l:cnum
    endif
  endfor

  " -2  cancel silently and stay in completion mode.
  " -3  cancel silently and leave completion mode.
  return -3
endfunction

function s:NVTagsComplete(base) abort
  if !exists('s:completer')
    return []
  endif
  return s:completer.complete(a:base)
endfunction

let s:completer_mdlink = {}

function! s:completer_mdlink.findstart(base) dict abort
  let l:line = getline('.')[:col('.') - 2]
  return match(l:line, '\[\zs[^\[)]\{-}$')
endfunction

function! s:completer_mdlink.complete(base) dict abort
  let l:dirs = NVTagsSearchPaths()
  let l:candidates = globpath(
        \ join(l:dirs, ','), get(g:, 'nvtags_completion_glob', '**/*.md'), 0, 1,
        \ )

  let l:refdir = expand('%:p:h')
  call map(l:candidates, 's:MarkdownLinkEntry(v:val, l:refdir)')
  call filter(l:candidates, 'match(v:val.abbr, a:base) >= 0')

  return l:candidates
endfunction

function! s:MarkdownLinkEntry(path, refdir) abort
  let [l:label, l:link] = s:MarkdownLink(a:path, a:refdir)
  return {'abbr': l:label, 'word': l:link[1:], 'menu': '[nvtags]'}
endfunction

let g:nvtags_completers = [s:completer_mdlink]

augroup mdcomplete
  autocmd!
  autocmd! FileType markdown,pandoc setlocal omnifunc=NVTagsOmnicomplete
augroup END
