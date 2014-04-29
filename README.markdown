# leiningen.vim

Static Vim support for [Leiningen][].

* `:Console` command to start a REPL or focus an existing instance if already
  running using [dispatch.vim][].
* Autoconnect [fireplace.vim][] to the REPL, or autostart it with `:Console`.
* [Navigation commands][projectionist.vim]: `:Esource`, `:Emain`, `:Etest`,
  and `:Eresource`.
* Alternate between test and implementation with `:A`.
* Use `:make` to invoke `lein`, complete with stacktrace parsing.
* Default [dispatch.vim][]'s `:Dispatch` to running the associated test file.
* `'path'` is seeded with the classpath to enable certain static Vim and
  [fireplace.vim][] behaviors.

[Leiningen]: http://leiningen.org/
[fireplace.vim]: https://github.com/tpope/vim-fireplace
[dispatch.vim]: https://github.com/tpope/vim-dispatch
[projectionist.vim]: https://github.com/tpope/vim-projectionist

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-leiningen.git
    git clone git://github.com/tpope/vim-projectionist.git
    git clone git://github.com/tpope/vim-dispatch.git
    git clone git://github.com/tpope/vim-fireplace.git

Once help tags have been generated, you can view the manual with
`:help leiningen`.

## FAQ

> Why does it sometimes take a few extra seconds for Vim to startup?

Much of the functionality of leiningen.vim depends on knowing the classpath.
When possible, this is retrieved from a [fireplace.vim][] connection, but if
not, this means a call to `lein classpath`.

Once retrieved, the classpath is cached until `project.clj` or
`~/.lein/profiles.clj` changes.

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
