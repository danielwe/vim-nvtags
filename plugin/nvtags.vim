" Dependencies
if !executable('rg')
    echoerr '`rg` is not installed. See https://github.com/BurntSushi/ripgrep for installation instructions.'
    finish
endif

" Settings
let s:pattern = shellescape(get(g:, 'nvtags_pattern', '(^|\s)#\S{3}'))
let s:globs = get(g:, 'nvtags_globs', [])
let s:globarg = ''
for s:glob in s:globs
  let s:globarg .= ' --glob ' . shellescape(s:glob)
endfor

" Create dynamic tag-based indexes
function! s:MarkdownLink(filename)
  return '['
        \ . trim(readfile(a:filename, '', 1)[0], '# ')
        \ . ']('
        \ . s:UrlEncode(a:filename)
        \ . ')'
endfunction

function! s:Filename(grepline)
  return split(a:grepline, ':')[0]
endfunction

function! s:InsertLinks(greplines)
  call append(
        \ line('.'),
        \ map(
        \   a:greplines,
        \   {_, grepline -> '* ' . s:MarkdownLink(s:Filename(grepline))}
        \ ),
        \ )
  call append(line('.'), '  ')
endfunction

command! -nargs=* NVTagsQuery
      \ call fzf#run({
      \   'sink*': funcref('s:InsertLinks'),
      \   'options': ['--exact', '--filter=<args>'],
      \   'source': join([
      \     'command',
      \     'rg',
      \     '--max-count 1',
      \     '--follow',
      \     '--color never',
      \     '--no-messages',
      \     '--no-heading',
      \     '--with-filename',
      \     '--ignore-case',
      \     s:globarg,
      \     s:pattern,
      \     '2>/dev/null',
      \   ]),
      \ })
command! -range NVTags execute 'NVTagsQuery' getline(<line1>)

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
  if ascii_code >= 48 && ascii_code <= 57
    return 0
  elseif ascii_code >= 65 && ascii_code <= 90
    return 0
  elseif ascii_code >= 97 && ascii_code <= 122
    return 0
  elseif a:character == "-" || a:character == "_" || a:character == "." || a:character == "~"
    return 0
  endif
  return 1
endfunction
