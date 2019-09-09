" Dependencies
if !executable('rg')
    echoerr '`rg` is not installed. See https://github.com/BurntSushi/ripgrep for installation instructions.'
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
  let queryline = '%(.*:\s*)?\zs%(%(''|\^|!\^?)?'
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
      \ }

function! s:RustToVimRegex(regex)
  let l:regex = a:regex
  for [pattern, substitution] in items(s:rust_to_vim_regex)
    let regex = substitute(l:regex, pattern, substitution, 'g')
  endfor
  return l:regex
endfunction

let s:prefix = get(g:, 'nvtags_tagline_prefix', '')
let s:tags = get(g:, 'nvtags_pattern', '#\w{2,}')
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
        \ . s:UrlEncode(a:filename)
        \ . ' "' . a:title . '"'
        \ . ')'
endfunction

function! s:MarkdownLinkFromGrep(grepline)
  let parts = split(a:grepline, ':')
  return '* ' . s:MarkdownLink(l:parts[0], trim(l:parts[-1]))
endfunction

function! s:AppendLinks(lnum, greplines)
  if len(a:greplines) > 0
    call append(a:lnum, ['  '] + map(a:greplines, 's:MarkdownLinkFromGrep(v:val)'))
  endif
endfunction

function! g:NVTagsGetQuery(queryline)
  return split(a:queryline, ':')[-1]
endfunction

command! -range -bar NVTagsClear execute "normal mt"
      \ | execute "<line2>normal A\<Space>\<Esc>d}`t"

command! -bang -nargs=? -range NVTags if !empty('<bang>') | <line2>NVTagsClear | endif
      \ | call fzf#run({
      \     'sink*': {greplines -> s:AppendLinks(<line2>, greplines)},
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
      \       '--sortr path',
      \       s:globarg,
      \       shellescape(g:nvtags_tagline_pattern),
      \       '2>/dev/null',
      \     ]),
      \   })
command! -bang -range NVTagsHere
      \ execute '<line2>NVTags<bang>' g:NVTagsGetQuery(getline('.'))

command! -bang NVTagsAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsHere<bang>' | normal ``
command! NVTagsClearAll
      \ execute 'global/' . g:nvtags_queryline_pattern . '/NVTagsClear' | normal ``

" URL encode a string, i.e., percent-encode characters if required. Adapted from
" http://www.danielbigham.ca/cgi-bin/document.pl?mode=Display&DocumentID=1053
function! s:UrlEncode(string)
  let result = ""
  let characters = split(a:string, '.\zs')
  for character in l:characters
    if s:CharacterRequiresUrlEncoding(l:character)
      let i = 0
      while l:i < strlen(l:character)
        let byte = strpart(l:character, l:i, 1)
        let decimal = char2nr(l:byte)
        let result = l:result . "%" . printf("%02x", l:decimal)
        let i += 1
      endwhile
    else
      let result = l:result . l:character
    endif
  endfor
  return result
endfunction

function! s:CharacterRequiresUrlEncoding(character)
  let ascii_code = char2nr(a:character)
  if ascii_code >= 48 && ascii_code <= 57  " digits
    return 0
  elseif ascii_code >= 65 && ascii_code <= 90  " uppercase letters
    return 0
  elseif ascii_code >= 97 && ascii_code <= 122  " lowercase letters
    return 0
  elseif
        \ a:character == "-"
        \ || a:character == "."
        \ || a:character == "_"
        \ || a:character == "~"  " unreserved special characters
    return 0
  elseif a:character == "/"  " reserved character used for reserved purpose
    return 0
  endif
  return 1
endfunction
