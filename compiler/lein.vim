" Vim compiler file

if exists("current_compiler")
  finish
endif
let current_compiler = "lein"

CompilerSet makeprg=lein
CompilerSet errorformat=%+G%.%#
      \,%\\&default=test
      \,%\\&start=repl
      \,%\\&force_start=repl%\\>%\\ze%.%#
