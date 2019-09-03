# vim-nvtags: Create dynamic tag-based indexes in vim

This plugin lets you create and update lists of links to #tagged files. It provides the
command `:NVTagsQuery <query>`, which recursively searches the current directory for
files with tags that match `<query>`, and inserts a list of links to the matching files.
The command `:NVTags` performs the same operation using the contents of the current
line, beyond the final colon, as the query.

These commands can for example be used to maintain a dynamic index to a collection of
notes.

## Tagging

By default, tags are defined by the pattern `'#\w\S+'`, i.e., a hash `#` followed by a
word character and then one or more non-whitespace characters. A custom pattern can be
configured using the `g:nvtags_pattern` variable, for example:

* `let g:nvtags_pattern = '@[A-Z][0-9A-Za-z]+'`: `@` followed by a capital letter and a
  one or more alphanumeric characters.

Since `ripgrep` is used for searching, the [Rust regex syntax](https://docs.rs/regex) applies.

A file's _tag line_ is taken to be the first line where a tag is present and sandwiched
between whitespaces or the beginning/end of the line (i.e., the full search pattern when
identifying the tag line is `'(^|\s){PATTERN}(\s|$)'`, where `{PATTERN}` is replaced
by the tag pattern). Hence, when setting a custom pattern with `g:nvtags_pattern`, it is
important to use a pattern that will consume the entirety of any valid tag, not merely a
prefix.

`:NVTagsQuery <query>` looks for files in which the tag line matches `<query>` using
the [`fzf` syntax](https://github.com/junegunn/fzf#search-syntax) with exact matching.

Typically, a tag line is added at or near the top of a file, like so:

```markdown
# Heading 1

 #all #the #tags

Lorem ipsum...
```

You may add some context if you wish:

```markdown
# Heading 1

Tags: #all #the #tags

Lorem ipsum...
```

## Querying

The `:NVTagsQuery` command matches tag lines to the search query using `fzf`'s `--exact`
mode. This not a fuzzy search, but individual search terms can be composed flexibly and
in any order. Examples:

* `:NVTagsQuery #tag1`: matches all files tagged with `#tag1`.
* `:NVTagsQuery #tag1 #tag2`: matches all files tagged with `#tag1` _and_ `#tag2`.
* `:NVTagsQuery #tag1 | #tag2`: matches all files tagged with `#tag1` _or_ `#tag2`.
* `:NVTagsQuery #tag1 !#tag2`: matches all files tagged with `#tag1` but _not_ `#tag2`.

All searches are case insensitive.

Note that the search terms match on substrings: `:NVTagsQuery #tag1` will also match
files tagged with `#tag12`, `#tag123`, and so on, and `:NVTagsQuery !#tag2` will only
match files not tagged with any of `#tag23`, `#tag234`, and so on. This can be used to
flexibly support hierarchical tagging: `#tag1` matches both `#tag1/subtag1` and
`#tag1/subtag2`.

The command `:NVTags` works just like `:NVTagsQuery`, but uses the contents of the
current line as the search query, skipping everything before the final colon `:`. It can
also be called with reference to a different line: `:.-1NVTags` uses the contents of the
preceding line (the result is still inserted below the current line).

## Filename filtering

By default, the `:NVTags*` commands search all files that are not hidden or excluded by
`.gitignore` and similar files. Custom filename filtering can be configured by setting
`g:nvtags_globs` to a list of glob patterns to include/exclude. Examples:

* `let g:nvtags_globs = ['*.md', '*.mkd', '*.markdown']`: Only include markdown
  files.
* `let g:nvtags_globs = ['!*.html']`: Exclude HTML files.

## Search result handling

For now, the `:NVTags*` commands insert a list of markdown links to the matching files,
grabbing the link text from the first line in the file and URL-encoding the address.
This is not customizable; perhaps the future will bring about more flexibility?

## Usage tips

You can create a dynamic index page for a note collection by doing something like this
in a file at the root directory of the collection:

```markdown
[...]

## Journal entries for 2019

Filter: #journal #2019
  
* [2019-08-28 New plugin out!](2019-08-28_new_plugin.md)
* [...]

## Current physics reading notes

Filter: #article #physics !#archived
  
* [[@Feynman1948]: Space-Time Approach to Non-Relativistic Quantum Mechanics](articles/feynman1948.md)
* [...]

## Work-related meetings and notes

Filter: #work #meeting | #note
  
* [2019-07-15 Meeting with stakeholders](projectA/2019-07-15_stakeholder_meeting.md)
* [2019-07-12 Recent progress](projectB/2019-07-12_recent_progress.md)
* [...]

[...]
```

Populate each section by placing the cursor on the `Filter:` line and running `:NVTags`.
A list of links to files with the desired tags will be inserted.

Try the following mapping to update an already populated list:

```vim
nmap <Leader>nt :put ='  '<CR>d}k:NVTags<CR>
```

## Similar plugins

This plugin is heavily inspired by, and built to complement,
<https://github.com/alok/notational-fzf-vim>, which provides interactive full-text
search based on the same mechanism.

### Proper documentation

Someday, maybe.
