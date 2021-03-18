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
        \ . NVTagsPercentEncode(a:filename)
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
      \       '--sortr path',
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

" Percent encode a URL, i.e., replace characters with percent codes as required. Adapted
" from http://www.danielbigham.ca/cgi-bin/document.pl?mode=Display&DocumentID=1053
function! NVTagsPercentEncode(string)
  return join(map(split(a:string, '\zs'), 's:PercentEncodeCharacter(v:val)'), "")
endfunction

function! NVTagsPercentDecode(string)
  return substitute(a:string, '\v\%(\x\x)', '\=printf("%c", "0x" . submatch(1))', 'g')
endfunction

function! s:PercentEncodeCharacter(char)
  let l:decimal = char2nr(a:char)
  if l:decimal >= 45 && l:decimal <= 57  " digits and -./
    return a:char
  elseif l:decimal >= 65 && l:decimal <= 90 " uppercase letters
    return a:char
  elseif l:decimal >= 97 && l:decimal <= 122 " lowercase letters
    return a:char
  elseif l:decimal == 95 || l:decimal == 126 " _~
    return a:char
  endif
  let l:bytes = []
  for l:i in range(strlen(a:char))
    call add(l:bytes, printf("%%%02X", char2nr(strpart(a:char, l:i, 1))))
  endfor
  return join(l:bytes, "")
endfunction

" Create operator functions that can be mapped to encode/decode text in a buffer
function! NVTagsPercentEncodeOp(type="")
  return s:PercentOp(a:type, "Encode")
endfunction

function! NVTagsPercentDecodeOp(type="")
  return s:PercentOp(a:type, "Decode")
endfunction

function! s:PercentOp(type, codec)
  if a:type == ""
    execute "set operatorfunc=NVTagsPercent" . a:codec . "Op"
    return 'g@'
  endif

  let l:sel_save = &selection
  let l:visual_marks_save = [getpos("'<"), getpos("'>")]

  try
    set selection=inclusive
    let l:select = {"line": "'[V']", "char": "`[v`]", "block": "`[\<c-v>`]"}
    normal! m`
    execute "noautocmd keepjumps normal! \<Esc>" get(l:select, a:type, "")
    execute 'noautocmd keepjumps %s/\v%V\_.*%V\_./\=NVTagsPercent' . a:codec . '(submatch(0))'
    execute "noautocmd keepjumps normal! \<Esc>"
    normal! ``
    nohl
  finally
    call setpos("'<", l:visual_marks_save[0])
    call setpos("'>", l:visual_marks_save[1])
    let &selection = l:sel_save
  endtry
endfunction

let s:extpattern = '\v\*\.(\f&[^./])+'
let s:extglobs = join(filter(s:globs, 'v:val =~# s:extpattern'), ",")

augroup nvtags
  if s:extglobs != ""
    execute "autocmd! BufRead" s:extglobs
          \ "setlocal includeexpr=NVTagsPercentDecode(v:fname)"
  endif
augroup END
