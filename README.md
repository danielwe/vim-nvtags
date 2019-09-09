# vim-nvtags: Create dynamic tag-based indexes in vim

This plugin lets you create and update lists of links to #tagged files. It provides the command `:NVTags <query>`, which recursively searches the current directory for files with tags that match `<query>`, and inserts a list of links to the matching files. The command `:NVTagsHere` extracts the query from the current line.

These commands can for example be used to maintain a dynamic index to a collection of notes.

## Tagging

By default, tags are defined by the pattern `'#\w{2,}'`, i.e., `#` followed by at least two word characters. A custom pattern can be configured using the `g:nvtags_pattern` variable; for example, if you want tags to be `@`-prefixed, capitalized, ASCII-only words with two or more letters, try `let g:nvtags_pattern = '@[[:upper:]][[:alpha:]]+'` .

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

The full pattern used for matching tag lines is available in `g:nvtags_tagline_pattern`. _Tip:_ if you also use [`notational-fzf-vim`](https://github.com/alok/notational-fzf-vim), try defining `command! -NT execute 'NV' g:nvtags_tagline_pattern`, and use `:NT` to filter tag lines interactively with fzf.

## Querying

The `:NVTags` command matches tag lines to a query using [`fzf`'s `--exact` mode](https://github.com/junegunn/fzf#search-syntax "Search syntax"), and appends a list of links to the matching files below the cursor line in the current buffer. This not a fuzzy search, but individual search terms can be composed flexibly and in any order. Examples:

* `:NVTags #tag1`: matches all files tagged with `#tag1`.
* `:NVTags #tag1 #tag2`: matches all files tagged with `#tag1` _and_ `#tag2`.
* `:NVTags #tag1 | #tag2`: matches all files tagged with `#tag1` _or_ `#tag2`.
* `:NVTags #tag1 !#tag2`: matches all files tagged with `#tag1` but _not_ `#tag2`.

Note that the search terms match on substrings: `:NVTags #tag1` will also match files tagged with `#tag12`, `#tag123`, and so on, and `:NVTags !#tag2` will only match files not tagged with any of `#tag23`, `#tag234`, and so on. This can be used to flexibly support hierarchical tagging: `#tag1` matches both `#tag1/subtag1` and `#tag1/subtag2`.

The command `:NVTagsHere`, uses the contents of the current line as the search query, discarding any prefix up to and including the last colon `:` on the line.

The commands can be called with an optional line number, e.g., `:5NVTags <query>` or `.-1NVTagsHere`. The line number detemines where the link list is appended, but not which line the query is extracted from: `:NVTagsHere` always takes its query from the current cursor line.

The command `:NVTagsAll` runs `:NVTagsHere` on all query lines in the buffer. If `g:nvtags_tagline_prefix` remains unset, a query line is essentially the same as a tag line, but also allows fzf modifiers around the tag search terms, i.e., one of `',^,!,!^` at the start and/or `$` at the end. If `g:nvtags_tagline_prefix` is nonempty, a query line is any such line _except_ a valid tag line.

Note that `:NVTagsAll` relies on a very rudimentary and experimental translation of regexes from rust syntax to vim syntax.<sup id="fnref1">[[1]](#fn1)</sup> The pattern used to match query lines can be inspected in `g:nvtags_queryline_pattern`.

## Search result handling

For now, `:NVTags[Here]` inserts a list of markdown links to the matching files, grabbing the link text from the first line in the file and URL-encoding the address as needed. The links are sorted in inverse alphabetical order by file path.<sup id="fnref2">[[2]](#fn2)</sup> This is not customizable; perhaps the future will bring about more flexibility?

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
  
* [2019-08-28 New plugin out!](20190828124102.md "#journal #vim")
* [...]

**Current physics reading notes**: #article #physics !#archived
  
* [Space-Time Approach to Non-Relativistic Quantum Mechanics [@Feynman1948]](20181224170000.md "#article #quantum #physics #Feynman")
* [...]

**Work meetings and talks**: #work #meeting | #talk
  
* [Meeting with project A stakeholders](20190715110311.md "#meeting #projectA #work")
* [Department HSE briefing](20190712143148.md "#talk #work #misc")
* [...]

[...]
```

Update each list by placing the cursor on the query line and running `:NVTagsHere!`. Update all of them at once by running `:NVTagsAll!`.

## Similar plugins

This plugin is heavily inspired by, and built to complement, <https://github.com/alok/notational-fzf-vim>, which provides interactive full-text search based on the same mechanism.

### Proper documentation

Someday, maybe.

---

1. <a id="fn1"></a>In addition to purely syntactical issues, some of the character classes are incompatible. Here we replace `\w` in rust with `\i` in vim in an attempt to approximate a consistent treatment of non-ASCII letters. [↩](#fnref1)

2. <a id="fn2"></a>The rationale for this sort order is that links will appear in inverse chronological order if timestamps are used as file names, e.g., `20190908225957.md`. Try a mapping like `nmap <Leader>nn :execute 'edit' . strftime("%Y%m%d%H%M%S") . '.md'<CR>` to automate this. [↩](#fnref2)
