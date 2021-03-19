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
function! s:TaglinePattern(prefix, tags)
  if !empty(a:prefix)
    let l:tagline_prefix = '\s*' . g:nvtags_tagline_prefix . '\s*:\s*'
  else
    let l:tagline_prefix =  '(?:.*:\s*)?'
  endif
  return '^' . l:tagline_prefix . '(?:' . a:tags . '(?:$|\s+))+$'
endfunction

function! s:QuerylinePattern(prefix, tags)
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

function! s:RustToVimRegex(regex)
  let l:regex = a:regex
  for [pattern, substitution] in items(s:rust_to_vim_regex)
    let regex = substitute(l:regex, pattern, substitution, 'g')
  endfor
  return l:regex
endfunction

let s:prefix = get(g:, 'nvtags_tagline_prefix', '')
let s:tags = get(g:, 'nvtags_pattern', '#\w{2,}(/|\w)*')
let g:nvtags_tagline_pattern = s:TaglinePattern(s:prefix, s:tags)
let g:nvtags_queryline_pattern = s:QuerylinePattern(s:prefix, s:tags)

let s:globs = get(g:, 'nvtags_globs', [])
let s:globarg = ''
for s:glob in s:globs
  let s:globarg .= ' --glob ' . shellescape(s:glob)
endfor

" Create dynamic tag-based indexes
function! s:MarkdownLink(filename, title)
  return '['
        \ . trim(readfile(a:filename, '', 1)[0], '# ')
        \ . ']('
        \ . PercentEncode(a:filename)
        \ . ' "' . a:title . '"'
        \ . ')'
endfunction

function! s:MarkdownLinkFromGrep(grepline)
  let parts = split(a:grepline, ':')
  return '* ' . s:MarkdownLink(l:parts[0], trim(l:parts[-1]))
endfunction

function! s:AppendLinks(lnum, greplines, n)
  if a:n > 0
    let l:n = a:n
  else
    let l:n = -1
  endif
  if len(a:greplines) > 0
    call append(a:lnum, ['  '] + map(a:greplines[:l:n], 's:MarkdownLinkFromGrep(v:val)'))
  endif
endfunction

function! NVTagsGetQuery(queryline)
  return trim(split(a:queryline, ':')[-1])
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
      \       s:globarg,
      \       shellescape(g:nvtags_tagline_pattern),
      \       '2>/dev/null',
      \     ]),
      \   })
command! -bang -range NVTagsHere
      \ execute '<line1>NVTags<bang>' NVTagsGetQuery(getline('.'))

command! -bang NVTagsAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsHere<bang>' | normal! ``
command! NVTagsClearAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsClear' | normal! ``
