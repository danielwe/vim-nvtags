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
    return '\[.*?\]\(('
          \ . percent#encoded_pattern()
          \ . '*/)?'
          \ . s:RustRegexEscape(percent#encode(expand("%:t")))
          \ . '.*\)'
  endfunction

  function! NVMentionsPattern() abort
    return s:RustRegexEscape(
          \ NVTagsTrimUID(NVTagsATXFirstH1(getline(1, '$')))
          \ )
  endfunction

  command! -bang NVBacklinks execute 'NV<bang>' NVBacklinksPattern()
  command! -bang NVMentions execute 'NV<bang>' NVMentionsPattern()
endif

if exists('g:pandoc#loaded') && g:pandoc#loaded && match(g:pandoc#modules#disabled, "completion") == -1
  let s:completer_pandoc = {}

  function! s:completer_pandoc.findstart(base) dict abort
    try
      return pandoc#completion#Complete(1, a:base)
    catch
      return -1
    endtry
  endfunction

  function! s:completer_pandoc.complete(base) dict abort
    try
      return pandoc#completion#Complete(0, a:base)
    catch
      return []
    endtry
  endfunction

  call add(g:nvtags_completers, s:completer_pandoc)
endif
