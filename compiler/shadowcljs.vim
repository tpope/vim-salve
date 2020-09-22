" Vim compiler file

if exists("current_compiler")
  finish
endif
let current_compiler = "shadowcljs"

CompilerSet makeprg=npx\ shadow-cljs
" CompilerSet makeprg=shadow-cljs
CompilerSet errorformat=%+G%.%#
      \,%\\&default=test
      \,%\\&start=clj-repl
      \,%\\&force_start=%\\w%\\+-repl%\\>%\\ze%.%#
