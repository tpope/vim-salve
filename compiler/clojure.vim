" Vim compiler file

if exists("current_compiler")
  finish
endif
let current_compiler = "clojure"

CompilerSet makeprg=clojure
" CompilerSet makeprg=clj
CompilerSet errorformat=%+G%.%#
      \,%\\&default=-A:default
      \,%\\&start=-Sdeps\ %%:p:h:s?.*?\\=g:salve_edn_deps?:S\ -m\ nrepl.cmdline\ --interactive\ --middleware\ %%:p:h:s?.*?\\=g:salve_edn_middleware?:S
