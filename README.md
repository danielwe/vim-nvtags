## vim-nvtags: Create dynamic tag-based indexes in vim

This plugin lets you create and update lists of links to #tagged files. It
provides the command `:NVTagsQuery <query>`, which recursively searches the
current directory for files with tags that match `<query>`, and inserts a list
of links to the matching files. The command `:NVTags` performs the same
operation using the contents of the current line as the query.

These commands can for example be used to maintain a dynamic index to
a collection of notes.

### Tagging

By default, tags are anything that matches the pattern `'(^|\s)#\S{3}'`, i.e.,
words starting with a hash '#' followed by three non-whitespace characters.
A custom pattern can be configured using the `g:nvtags_pattern` variable, for
example:

* `let g:nvtags_pattern = '(^|\s)@[A-Z][A-Za-z]'`: words starting with '@'
  followed by a capital letter and then another letter.

The _first line_ in a file matching the tag pattern is considered the file's
tag line. `:NVTagsQuery <query>` looks for files in which this tag line matches
`<query>`.

Typical usage is to add a tag line at or near the top of a file, like so:
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

### Querying

The `:NVTagsQuery` command matches tag lines to the search query using `fzf`'s
`--exact` mode. This not a fuzzy search, but individual search terms can be
composed flexibly and in any order. Examples:

* `:NVTagsQuery #tag1`: matches all files tagged with `#tag1`.
* `:NVTagsQuery #tag1 #tag2`: matches all files tagged with `#tag1` _and_ `#tag2`.
* `:NVTagsQuery #tag1 | #tag2`: matches all files tagged with `#tag1` _or_ `#tag2`.
* `:NVTagsQuery #tag1 !#tag2`: matches all files tagged with `#tag1` but _not_ `#tag2`.

All searches are case insensitive.

Note that the searches perform prefix matches: `:NVTagsQuery #tag1` will also
match files tagged with `#tag12`, `#tag123`, and so on, and `:NVTagsQuery
!#tag2` will only match files not tagged with any of `#tag23`, `#tag234`, and
so on. This can be used to flexibly support hierarchical tagging: `#tag1`
matches both `#tag1/subtag1` and `#tag1/subtag2`.

The command `:NVTags` works just like `:NVTagsQuery`, but uses the contents of
the current line as the search query. It can also be called with reference to
a different line: `:.-1NVTags` uses the contents of the preceding line as the
query (the result is still inserted below the current line).

### Filename filtering

By default, the `:NVTags*` commands search all files that are not hidden or
excluded by `.gitignore` and similar files. Custom filename filtering can be
configured by setting `g:nvtags_globs` to a list of glob patterns to
include/exclude. Examples:

* `let g:nvtags_globs = ['*.md', '*.mkd', '*.markdown']`: Only include markdown
  files.
* `let g:nvtags_globs = ['!*.html']`: Exclude HTML files.

### Search result handling

For now, the `:NVTags*` commands insert a list of markdown links to the
matching files, grabbing the link text from the first line in the file and URL-encoding
the address. This is not customizable; perhaps the future will bring about more
flexibility?

### Usage tips

You can create a dynamic index page for a note collection by doing something
like this in a file at the root directory of the collection:
```markdown
[...]

## Journal entries for 2019
 #journal #2019
  
 * [2019-08-28 New plugin out!](2019-08-28_new_plugin.md)
 * [...]

## Current physics reading notes
 #article #physics !#archived
  
 * [[@Feynman1948]: Space-Time Approach to Non-Relativistic Quantum Mechanics](articles/feynman1948.md)
 * [...]

## Work-related meetings and notes
 #work #meeting | #note
  
 * [2019-07-15 Meeting with stakeholders](projectA/2019-07-15_stakeholder_meeting.md)
 * [2019-07-12 Recent progress](projectB/2019-07-12_recent_progress.md)
 * [...]

[...]
```
Populate each section by placing the cursor on the line below the section
headings and running `:NVTags`. A list of links to files with the desired tags
will be inserted. File names and folder organization do not affect search hits,
and can be applied at the user's discretion.

Try the following mapping to update an already populated list:
```vim
nmap <Leader>nv :put ='  '<CR>d}k:NVTags<CR>
```

### Similar plugins

This plugin is heavily inspired by, and built to complement,
https://github.com/alok/notaional-fzf-vim, which provides interactive full-text
search based on the same mechanism.

### Proper documentation

Someday, maybe.
