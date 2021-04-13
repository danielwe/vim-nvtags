" notational-vim-fzf interoperability
if exists(':NV') == 2
  if !exists('g:nvtags_search_paths')
    let g:nvtags_search_paths = g:nv_search_paths
  end

  command! -bang -nargs=? NT execute 'NV<bang>' g:nvtags_tagline_pattern
        \ | if empty(<q-bang>) | call feedkeys(<q-args>) | endif
  command! NTHere execute 'NT' NVTagsGetQuery(getline('.'))

  function! s:RustRegexEscape(str) abort
    return escape(a:str, '\.+*?()|[]{}^$')
  endfunction

  function! NVBacklinksPattern() abort
    return '\[.*\]\(([0-9A-Za-z%'
          \ . g:percent_unreserved_nonalnum
          \ . g:percent_permitted_reserved
          \ . ']*/)?'
          \ . s:RustRegexEscape(PercentEncode(expand("%:t")))
          \ . '.*\)'
  endfunction

  function! NVMentionsPattern() abort
    return s:RustRegexEscape(
          \ NVTagsTrimUID(NVTagsMarkdownTitle(getline(1, '$')))
          \ )
  endfunction

  command! -bang NVBacklinks execute 'NV<bang>' NVBacklinksPattern()
  command! -bang NVMentions execute 'NV<bang>' NVMentionsPattern()
endif

if exists('g:pandoc#loaded') && g:pandoc#loaded && match(g:pandoc#modules#disabled, "completion") == -1
  let s:completer_pandoc = {}

  function! s:completer_pandoc.findstart(base) dict abort
    return pandoc#completion#Complete(1, a:base)
  endfunction

  function! s:completer_pandoc.complete(base) dict abort
    return pandoc#completion#Complete(0, a:base)
  endfunction

  call add(g:nvtags_completers, s:completer_pandoc)
endif
