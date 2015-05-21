" Vim compiler file

if exists("current_compiler")
  finish
endif
let current_compiler = "boot"

CompilerSet makeprg=boot
CompilerSet errorformat=%+G
