# salve.vim

Static Vim support for [Leiningen][] and [Boot][].

> Leiningen ran... [the ants] would get to him soon, despite the salve on
> his boots.

-- from "Leiningen versus the Ants"

## Features

* `:Console` command to start a REPL or focus an existing instance if already
  running using [dispatch.vim][].
* Autoconnect [fireplace.vim][] to the REPL, or autostart it with `:Console`.
* [Navigation commands][projectionist.vim]: `:Esource`, `:Emain`, `:Etest`,
  and `:Eresource`.
* Alternate between test and implementation with `:A`.
* Use `:make` to invoke `lein` or `boot`, complete with stacktrace parsing.
* Default [dispatch.vim][]'s `:Dispatch` to running the associated test file.
* `'path'` is seeded with the classpath to enable certain static Vim and
  [fireplace.vim][] behaviors.

[Leiningen]: http://leiningen.org/
[Boot]: http://boot-clj.com/
[fireplace.vim]: https://github.com/tpope/vim-fireplace
[dispatch.vim]: https://github.com/tpope/vim-dispatch
[projectionist.vim]: https://github.com/tpope/vim-projectionist

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-salve.git
    git clone git://github.com/tpope/vim-projectionist.git
    git clone git://github.com/tpope/vim-dispatch.git
    git clone git://github.com/tpope/vim-fireplace.git

Once help tags have been generated, you can view the manual with
`:help salve`.

## FAQ

> Why does it sometimes take a few extra seconds for Vim to startup?

Much of the functionality of salve.vim depends on knowing the classpath.
When possible, this is retrieved from a [fireplace.vim][] connection, but if
not, this means a call to `lein classpath` or `boot show --fake-classpath`.

Once retrieved, the classpath is cached until a project manifest file
changes: for Leiningen `project.clj` or `~/.lein/profiles.clj`, for Boot
`build.boot` or `~/.boot/profile.boot`.

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
