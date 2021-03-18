# vim-nvtags: Create dynamic tag-based indexes in vim

This plugin lets you create and update lists of links to #tagged files. It provides the command `:NVTags <query>`, which recursively searches the current directory for files with tags that match `<query>`, and inserts a list of links to the matching files. The command `:NVTagsHere` extracts the query from the current line.

These commands can for example be used to maintain a dynamic index to a collection of notes.

## Tagging

By default, tags are defined by the pattern `'#\w{2,}(/|\w)*'`, i.e., `#` followed by at least two word characters, and then any sequence of forward slashes and more word characters. A custom pattern can be configured using the `g:nvtags_pattern` variable; for example, if you want tags to be `@`-prefixed, capitalized, ASCII-only words with two or more letters, try `let g:nvtags_pattern = '@[[:upper:]][[:alpha:]]+'`.

Since `ripgrep` is used for searching, the [Rust regex syntax](https://docs.rs/regex) applies.

A file's _tag line_ is the first line that contains a sequence of white space-delimited tags, and an optional, arbitrary prefix separated from the tags by a colon `:`. If you want to enforce a particular prefix, set the variable `g:nvtags_tagline_prefix` to a matching pattern; for example, use `let g:nvtags_tagline_prefix = '[Tt]ags'` to only allow tag lines of the form `tags: #tag1 #tag2 [...]`, with optional capitalization. Any amount of white space is allowed around the prefix, the `:` separator, and the tags.

Typically, a tag line is added at or near the top of a file, like so:

```markdown
# Heading 1

  #all #the #tags

Lorem ipsum...
```

Or, with a prefix, (required required if `let g:nvtags_tagline_prefix` is set):

```markdown
# Heading 1

Tag list: #all #the #tags

Lorem ipsum...
```

The full pattern used for matching tag lines is available in `g:nvtags_tagline_pattern`.

## Querying

The `:NVTags` command matches tag lines to a query using [`fzf`'s `--exact` mode](https://github.com/junegunn/fzf#search-syntax "Search syntax"), and appends a list of links to the matching files below the cursor line in the current buffer. This not a fuzzy search, but individual search terms can be composed flexibly and in any order. Examples:

* `:NVTags #tag1`: matches all files tagged with `#tag1`.
* `:NVTags #tag1 #tag2`: matches all files tagged with `#tag1` _and_ `#tag2`.
* `:NVTags #tag1 | #tag2`: matches all files tagged with `#tag1` _or_ `#tag2`.
* `:NVTags #tag1 !#tag2`: matches all files tagged with `#tag1` but _not_ `#tag2`.

Note that the search terms match on substrings: `:NVTags #tag1` will also match files tagged with `#tag12`, `#tag123`, and so on, and `:NVTags !#tag2` will only match files not tagged with any of `#tag23`, `#tag234`, and so on. This can be used to flexibly support hierarchical tagging: `#tag1` matches both `#tag1/subtag1` and `#tag1/subtag2`.

The query can optionally begin with a number to limit the number of search results. For example, `:NVTags 5 #tag1` will return up to 5 files tagged with `#tag1`. These will be the first 5 lines returned from the search; see [Search result handling](#search-result-handling) for sort order.

The command `:NVTagsHere`, uses the contents of the current line as the search query, discarding any prefix up to and including the last colon `:` on the line.

The commands can be called with an optional line number, e.g., `:5NVTags <query>` or `.-1NVTagsHere`. The line number detemines where the link list is appended, but not which line the query is extracted from: `:NVTagsHere` always takes its query from the current cursor line.

The command `:NVTagsAll` runs `:NVTagsHere` on all query lines in the buffer. If `g:nvtags_tagline_prefix` remains unset, a query line is essentially the same as a tag line, but also allows fzf modifiers around the tag search terms, i.e., one of `',^,!,!^` at the start and/or `$` at the end. If `g:nvtags_tagline_prefix` is nonempty, a query line is any such line _except_ a valid tag line.

Note that `:NVTagsAll` relies on a very rudimentary and experimental translation of regexes from rust syntax to vim syntax.<sup id="fnref1">[[1]](#fn1)</sup> The pattern used to match query lines can be inspected in `g:nvtags_queryline_pattern`.

### Interoperability with `notational-vim-fzf`

If [`notational-fzf-vim`](https://github.com/alok/notational-fzf-vim) is installed, this plugin defines two additional commands for interactive tag searches:

* `:NT[!] <query>`:
Starts an interactive fzf search over tag lines; like running `:execute 'NV[!]' g:nvtags_tagline_pattern`. The fzf query field will be prefilled with any arguments passed to `:NT` (this only works without the `!`).

* `:NTHere`:
Like `:NT`, but extracts the prefilled fzf query from the current line, like `:NVTagsHere`.

## Search result handling

For now, `:NVTags[Here]` inserts a list of markdown links to the matching files, grabbing the link text from the first line in the file and [percent-encoding](#percent-encodingdecoding) the address to obtain a valid URL. The links are sorted in inverse alphabetical order by file path.<sup id="fnref2">[[2]](#fn2)</sup> This is not customizable; perhaps the future will bring about more flexibility?

The command `:NVTagsClear` deletes a previously appended list of links below the given line.

The banged commands `:NVTags!`, `NVTagsHere!`, and `:NVTagsAll!` _replace_ any previously inserted list of links instead of merely appending.

## Filename filtering

By default, the `:NVTags*` commands search all files that are not hidden or excluded by `.gitignore` and similar files. Custom filename filtering can be configured by setting `g:nvtags_globs` to a list of glob patterns to include/exclude. Examples:

* `let g:nvtags_globs = ['*.md', '*.mkd', '*.markdown']`: Only include markdown files.
* `let g:nvtags_globs = ['!*.html']`: Exclude HTML files.

## Usage tips

You can create a dynamic index page for a note collection by doing something like this in a file at the root directory of the collection:

```markdown
[...]

**Journal**: #journal
  
* [2019-08-28 New plugin out!](New%20plugin%20out%21%2020190828124102.md "#journal #vim")
* [...]

**Current physics reading notes**: #article #physics !#archived
  
* [Space-Time Approach to Non-Relativistic Quantum Mechanics [@Feynman1948]](%40Feynman1948%2020181224170000.md "#article #physics/quantum #Feynman")
* [...]

**The two latest work meetings and talks**: 2 #work #meeting | #talk
  
* [Meeting with project A stakeholders](Meeting%20with%20project%20A%20stakeholders%2020190715110311.md "#meeting #work/projectA")
* [Department HSE briefing](Department%20HSE%20briefing%2020190712143148.md "#talk #work")

[...]
```

Update each list by placing the cursor on the query line and running `:NVTagsHere!`. Update all of them at once by running `:NVTagsAll!`.

## Percent-encoding/decoding

The `:NVTags[Here]` commands take care to percent-encode filenames as required to obtain a valid URL and thus a valid markdown link. Percent-encoding means replacing special characters with their literal byte values written out as `%XX`, where `X` represents a hexadecimal digit. For example, a space becomes `%20`. See <https://en.wikipedia.org/wiki/Percent-encoding> for details.

The implementation of percent-encoding in this plugin is exposed through the functions `NVTagsPercent{Encode,Decode}`, which take a single string argument and returns the corresponding encoded/decoded string. Perhaps more usefully, the plugin also provides operator functions `NVTagsPercent{Encode,Decode}Op`, which can be mapped to operators that replace a text object or selection with its percent encoded/decoded counterpart. To make use of this, put something like the following in your `.vimrc`:

```vim
" Percent encoding/decoding
nmap <silent> <expr> <Leader>ne NVTagsPercentEncodeOp()
vmap <silent> <expr> <Leader>ne NVTagsPercentEncodeOp()
nmap <silent> <expr> <Leader>nd NVTagsPercentDecodeOp()
vmap <silent> <expr> <Leader>nd NVTagsPercentDecodeOp()
```

Hit `<Leader>ndi(` inside the URL part of a percent-encoded markdown link to see this in action.

### Fixing `gf`

The built-in `gf` keybinding for opening the file under the cursor does not decode percent-encoded filenames, and hence fails to open links inserted by this plugin if the filename contains special characters. This plugin fixes this problem by setting `includeexpr`, but only for file types given in `g:nvtags_globs` (see below). Specifically, it considers only inclusive file type globs, i.e., globs of the form `*.ext`, and sets `includeexpr` for all matching buffers.

If you want to use this functionality for file types that you do not want to list in `g:nvtags_globs`, define the following autocommand in your `.vimrc`:

```vim
augroup DecodeLinks
  " Fix gf for html
  autocmd! BufRead *.html setlocal includeexpr=NVTagsPercentDecode(v:fname)
augroup END
```

Note that some plugins, such as [vim-pandoc](https://github.com/vim-pandoc/vim-pandoc), may override `gf` for certain file types such that `includeexpr` is no longer used, rendering the fix provided here useless. The workaround is to disable this behavior by the implicated plugin, i.e., adding something like `let g:pandoc#modules#disabled = ["hypertext"]` or `let g:pandoc#hypertext#use_default_mappings = 0` to your `.vimrc`.

## Similar plugins

This plugin is heavily inspired by, and built to complement, <https://github.com/alok/notational-fzf-vim>, which provides interactive full-text search based on the same mechanism.

## Proper documentation

Someday, maybe.

---

1. <a id="fn1"></a>In addition to purely syntactical issues, some of the character classes are incompatible. Here we replace `\w` in rust with `\i` in vim in an attempt to approximate a consistent treatment of non-ASCII letters. [↩](#fnref1)

2. <a id="fn2"></a>The rationale for this sort order is that links will appear in inverse chronological order if timestamps are used as file names, e.g., `20190908225957.md`. Try a mapping like `nmap <Leader>nn :execute 'edit' . strftime("%Y%m%d%H%M%S") . '.md'<CR>` to automate this. [↩](#fnref2)
