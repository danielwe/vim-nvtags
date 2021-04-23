# vim-nvtags: Create dynamic tag-based indexes in vim

This plugin lets you create and update lists of links to #tagged files. It provides the command `:NVTags <query>`, which recursively searches the current directory for files with tags that match `<query>`, and inserts a list of links to the matching files. The command `:NVTagsHere` extracts the query from the current line.

These commands can for example be used to maintain a dynamic index to a collection of notes.

## Dependencies

[`vim-percent`](https://github.com/danielwe/vim-percent) must be installed and loaded before `vim-nvtags`. Handles percent-encoding of file paths in markdown links.

## Tagging

By default, tags are defined by the pattern `'#\w{2,}(/|\w)*'`, i.e., `#` followed by at least two word characters, and then any sequence of forward slashes and more word characters. A custom pattern can be configured using the `g:nvtags_pattern` variable; for example, if you want tags to be `@`-prefixed, capitalized, ASCII-only words with two or more letters, try `let g:nvtags_pattern = '@[[:upper:]][[:alpha:]]+'`.

Since `ripgrep` is used for searching, the [Rust regex syntax](https://docs.rs/regex) applies.

A file's _tag line_ is the first line that contains a sequence of white space-delimited tags, and an optional, arbitrary prefix separated from the tags by a colon `:`. If you want to enforce a particular prefix, set the variable `g:nvtags_tagline_prefix` to a matching pattern; for example, use `let g:nvtags_tagline_prefix = '[Tt]ags'` to only allow tag lines of the form `tags: #tag1 #tag2 [...]`, with optional capitalization. Any amount of white space is allowed around the prefix, the `:` separator, and the tags.

Typically, a tag line is added at or near the top of a file, like so:

```markdown
# Heading 1

  #all #the/tags

Lorem ipsum...
```

Or, with a prefix, (required if `let g:nvtags_tagline_prefix` is set):

```markdown
# Heading 1

Tags: #all #the/tags

Lorem ipsum...
```

The full pattern used for matching tag lines can be obtained by calling `nvtags#pattersn#tagline()`.

## Querying

The `:NVTags` command matches tag lines to a query using [`fzf`'s `--exact` mode](https://github.com/junegunn/fzf#search-syntax "Search syntax"), and appends a list of links to the matching files below the cursor line in the current buffer. This not a fuzzy search, but individual search terms can be composed flexibly and in any order. Examples:

* `:NVTags #tag1`: matches all files tagged with `#tag1`.
* `:NVTags #tag1 #tag2`: matches all files tagged with `#tag1` _and_ `#tag2`.
* `:NVTags #tag1 | #tag2`: matches all files tagged with `#tag1` _or_ `#tag2`.
* `:NVTags #tag1 !#tag2`: matches all files tagged with `#tag1` but _not_ `#tag2`.

Note that the search terms match on substrings: `:NVTags #tag1` will also match files tagged with `#tag12`, `#tag123`, and so on, and `:NVTags !#tag2` will only match files not tagged with any of `#tag23`, `#tag234`, and so on. This can be used to flexibly support hierarchical tagging: `#tag1` matches both `#tag1/subtag1` and `#tag1/subtag2`.

The query can optionally begin with a number to limit the number of search results. For example, `:NVTags 5 #tag1` will return up to 5 files tagged with `#tag1`. These will be the first 5 lines returned from the search; see [Search result handling](#search-result-handling) for sort order. (Note that there seems to be a strange bug in how vim parses command arguments that can sometimes break this functionality when the cursor is on the last line in the buffer and the command is called without an explicit line number.)

The search by default starts in the working directory, but additional root directories can be configured using the variable `g:nvtags_search_paths`, which should contain a list of folder paths. The search will combine matches from the current directory and all folders listed in this variable.

The command `:NVTagsHere`, uses the contents of the current line as the search query, discarding any prefix up to and including the last colon `:` on the line.

The commands can be called with an optional line number, e.g., `:5NVTags <query>` or `.-1NVTagsHere`. The line number determines where the link list is inserted, but not which line the query is extracted from: `:NVTagsHere` always takes its query from the current cursor line.

The command `:NVTagsAll` runs `:NVTagsHere` on all query lines in the buffer. If `g:nvtags_tagline_prefix` remains unset, a query line is essentially the same as a tag line, but also allows fzf modifiers around the tag search terms, i.e., one of `',^,!,!^` at the start and/or `$` at the end. If `g:nvtags_tagline_prefix` is nonempty, a query line is any such line _except_ a valid tag line.

Note that `:NVTagsAll` relies on a very rudimentary and experimental translation of regex patterns from rust syntax to vim syntax.<sup id="fnref1">[[1]](#fn1)</sup> The pattern used to match query lines can be obtained from in `nvtags#patterns#queryline`.

## Search result handling

`:NVTags[Here]` inserts a list of links to the matching files, grabbing the link label from the first H1 ATX header in the file. The type of link can be customized through the parameter `g:nvtags_link_type`; valid values are `'wiki'` and `'markdown'`, the default is `'wiki'`. For wiki links, the label is not added if it is identical to the filename and thus redundant. For markdown links, the file path is percent-encoded to obtain a valid URL, and the contents of the file's tag line is appended as mouseover text (link "title").

The links are sorted according to the value of `g:nvtags_sort_arg`, which should specify the relevant command line argument to `rg`; the default is `--sortr modified`, which sorts files in inverse order of last modification time, such that the last modified matching file is listed first.

A Zettelkasten-style UID will be removed from the H1 header to produce a less cluttered link label. To customize the UID pattern, set the variable `g:nvtags_uid_pattern` to an appropriate vim regex pattern. The default is `\v(^\d{12,}|\d{12,}$)`, i.e., 12 or more consecutive digits at the beginning or end of the label.

The number of lines in each file to scan for headers can be customized by setting `g:nvtags_label_scan_num_lines`; the default is `10`. If no H1 header is found the link label will be the file name without extension.

The command `:NVTagsClear` deletes a previously appended list of links below the given line. This functionality relies on the two blank spaces inserted on the line between the queryline and the link list inserted by `:NVTags[Here]`, so it's a good idea to not do too much editing of the inserted link lines.

The banged commands `:NVTags!`, `NVTagsHere!`, and `:NVTagsAll!` _replace_ any previously inserted list of links instead of merely appending, by calling `:NVTagsClear` before inserting.

## Filename filtering

The `:NVTags*` commands start from the working directory and search all files that are not hidden or excluded by `.gitignore` and similar files and that matches all glob patterns in the list `g:nvtags_globs`. The default is `['*.md', '*.mkd, '*.markdown']`, matching the most common markdown extensions. Some possibilities are:

* `let g:nvtags_globs = ['*.md']`: Only include the most common markdown extension.
* `let g:nvtags_globs = ['!*.html', '!templates/*']`: Exclude HTML files and files in the `templates` folder.

## Completion

The plugin provides an omnifunc for autocompletion of wiki and markdown links, inspired by [wiki.vim](https:/github.com/lervag/wiki.vim) but with somewhat different functionality, including [integrating pandoc bibliography completion](#interoperability-with-vim-pandoc) if available.

The omnifunc is enabled for files with extensions in `g:nvtags_extensions`; the default is `['md', 'mkd', 'markdown']`. Make sure to load this plugin after `pandoc` and `wiki.vim` in order for this omnifunc to take precedence.

The omnifunc looks for files in the same directories as `NVTags` et al., see [Querying](#querying). The files to match can be specified by setting the variable `g:nvtags_completion_glob`; the default is `'**/*'`, which matches any file with extension at any depth in the folder hierarchies below the search paths (the rationale for not restricting to a markdown extension by default is to enable completing markdown image links).

Currently, the omnifunc has five completion modes:

* `[wiki]`: The completion alternatives following `[[<input>` are relative paths to files.
* `[mdurl]`: The completion alternatives following `[<label>](<input>` are markdown link URLs to files.
* `[mdlabel]`: The completion alternatives following `[<input>` are full markdown links to files, with label and URL as described under [Search result handling](#search-result-handling).
* `[anchor]`: The completion alternatives following `[[<file path>#<input>` and `[<label>](<file path>#<input>` are anchors to headers in the given file. An attempt is made to approximate as closely as possible the mapping of headers to anchors used in common markdown renderers such as github.
* `[wikilabel]`: The sole completion alternative following `[[<file path>|<input>` is the link label extracted from the given file, as described under [Search result handling](#search-result-handling). Similarly, the completion alternative following `[[<file_path>#<anchor>|<input>` is the contents of the header that the anchor points to.

The selected mode is the one that produces the shortest `<input>` string. In all cases, the text displayed in the popup menu is the link label as described under [Search result handling](#search-result-handling), or the relevant header in the case of anchor completion.

Suggested triggers for supported autocompletion engines can be obtained through functions under the `nvtags#triggers` namespace. The only supported engine at the moment is <https://github.com/Valloric/YouCompleteMe>. To use these triggers, add the following to your `.vimrc`:

```vim
if !exists('g:ycm_semantic_triggers')
  let g:ycm_semantic_triggers = {}
endif
augroup ycm_triggers
  autocmd!
  autocmd! VimEnter *
        \| let g:ycm_semantic_triggers.pandoc = nvtags#triggers#ycm('pandoc')
        \| let g:ycm_semantic_triggers.markdown = nvtags#triggers#ycm('markdown')
augroup END
```

The filename argument is optional but allows the triggers to be adapted as appropriate for integrated third-party omnifuncs. Specifically, this will add `@` as a trigger for the `pandoc` filetype if pandoc bibliography completion is loaded and [integrated](#interoperability-with-vim-pandoc).

Note that the suggested will _not_ trigger the `[mdlabel]` completion mode; autotriggering this is arguably too intrusive, and these completion alternatives will often be discarded by the autocompletion engine anyway for being longer than 80 characters. Hit `<c-x><c-o>` to trigger this completion mode manually when desired (or manually add `'['` to the list of triggers if you really want to: `nvtags#triggers#ycm() + ['[']`). (Note that if you're using YouCompleteMe the completion menu will likely flash and disappear on the first invocation of `<c-x><c-o>` at a given location; hit `<c-x><c-o>` again to make it stay. An alternative is to trigger YouCompleteMe manually using `<c-space>`, but note that the results will then be subject to the 80 character limit.)

## Interoperability with `notational-vim-fzf`

If [`notational-fzf-vim`](https://github.com/alok/notational-fzf-vim) is installed, this plugin defines four additional commands:

* For interactive tag searches:
  * `:NT[!] <query>`:
  Starts an interactive fzf search over tag lines; like running `:execute 'NV[!]' nvtags#patterns#tagline`. The fzf query field will be prefilled with any arguments passed to `:NT` (this only works without the `!`).

  * `:NTHere`:
  Like `:NT`, but extracts the prefilled fzf query from the current line, like `:NVTagsHere`.
* For finding files that link to or mention the current file:
  * `NVBacklinks[!]`:
  Starts an interactive fzf search over lines that contain a link to the current file. More precisely, matching lines are lines with a link to a file of the same name regardless of path/directory, so false positives can occur if the name of the current file is not unique or there exist links to nonexistent files.

  * `NVMentions[!]`:
  Starts an interactive fzf search over lines that contain the title of the current file. The title is extracted from the file contents as explained under [Search result handling](#search-result-handling).

In addition, if the variable `g:nvtags_search_paths` is not set manually it will be set to the same as `g:nv_search_paths`.

## Interoperability with `vim-pandoc`

If [`vim-pandoc`](https://github.com/vim-pandoc/vim-pandoc) is loaded with the completion module enabled, the provided omnifunc integrates with the pandoc omnifunc, so both link and bibliography completion work

## Usage tips

You can create a dynamic index page for a note collection by doing something like this in a file at the root directory of the collection:

```markdown
[...]

**Journal**: #journal
  
* [2019-08-28 New plugin out!](New%20plugin%20out%21%20201908281241.md "#journal #vim")
* [...]

**Current physics reading notes**: #article #physics !#archived
  
* [Space-Time Approach to Non-Relativistic Quantum Mechanics [@Feynman1948]](@Feynman1948%20201812241700.md "#article #physics/quantum #Feynman")
* [...]

**The two latest work meetings and talks**: 2 #work #meeting | #talk
  
* [Meeting with project A stakeholders](Meeting%20with%20project%20A%20stakeholders%20201907151103.md "#meeting #work/projectA")
* [Department HSE briefing](Department%20HSE%20briefing%20201907121431.md "#talk #work")

[...]
```

Update each list by placing the cursor on the query line and running `:NVTagsHere!`. Update all of them at once by running `:NVTagsAll!`. The links shown above are markdown links as produced with `let g:nvtags_link_type == 'markdown'`.

## Similar plugins

This plugin is inspired by, and built to complement, <https://github.com/alok/notational-fzf-vim>, which provides interactive full-text search based on the same mechanism. The completion omnifunc is based on the one in <https://github.com/lervag/wiki.vim>.

## Proper documentation

Someday, maybe.

---

1. <a id="fn1"></a>In addition to purely syntactical issues, some of the character classes are incompatible. Here we replace `\w` in rust with `\i` in vim in an attempt to approximate a consistent treatment of non-ASCII letters. [↩](#fnref1)
