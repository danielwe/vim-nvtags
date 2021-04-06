" notational-vim-fzf interoperability
if exists(':NV') == 2
  command! -bang -nargs=? NT execute 'NV<bang>' g:nvtags_tagline_pattern
        \ | if empty(<q-bang>) | call feedkeys(<q-args>) | endif
  command! NTHere execute 'NT' NVTagsGetQuery(getline('.'))

  function! s:RustRegexEscape(str)
    return escape(a:str, '\.+*?()|[]{}^$')
  endfunction

  function! NVBacklinksPattern()
    return '\[.*\]\(([0-9A-Za-z%'
          \ . g:percent_unreserved_nonalnum
          \ . g:percent_permitted_reserved
          \ . ']*/)?'
          \ . s:RustRegexEscape(PercentEncode(expand("%:t")))
          \ . '.*\)'
  endfunction

  function! NVMentionsPattern()
    let l:curpos = getcurpos()
    call cursor(1, 1)
    let l:titleline = search('\v^#\ ', 'c')
    call cursor(l:curpos[1], l:curpos[2])
    return s:RustRegexEscape(trim(getline(l:titleline)[2:]))
  endfunction

  command! -bang NVBacklinks execute 'NV<bang>' NVBacklinksPattern()
  command! -bang NVMentions execute 'NV<bang>' NVMentionsPattern()
endif
