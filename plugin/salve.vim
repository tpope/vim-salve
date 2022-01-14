" Location: plugin/salve.vim
" Author:   Tim Pope <http://tpo.pe/>

if exists('g:loaded_salve') || v:version < 800
  finish
endif
let g:loaded_salve = 1

if !exists('g:classpath_cache')
  let g:classpath_cache = '~/.cache/vim/classpath'
endif

if !exists('g:salve_edn_deps')
  let g:salve_edn_deps = '{:deps {cider/cider-nrepl {:mvn/version "RELEASE"} }}'
endif
if !exists('g:salve_edn_middleware')
  let g:salve_edn_middleware = '[cider.nrepl/cider-middleware]'
endif

if !isdirectory(expand(g:classpath_cache))
  call mkdir(expand(g:classpath_cache), 'p')
endif

function! s:portfile() abort
  if !exists('b:salve')
    return ''
  endif

  let root = b:salve.root
  let portfiles = get(b:salve, 'portfiles', []) + [root.'/.nrepl-port', root.'/target/repl-port', root.'/target/repl/repl-port']

  for f in portfiles
    if getfsize(f) > 0
      return f
    endif
  endfor
  return ''
endfunction

function! s:repl(background, args) abort
  let args = empty(a:args) ? '' : ' ' . a:args
  let portfile = s:portfile()
  if a:background && !empty(portfile)
    return
  endif
  let cd = haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  try
    let cmd = b:salve.start_cmd
    execute cd fnameescape(b:salve.root)
    if exists(':Start') == 2
      execute 'Start'.(a:background ? '!' : '') '-title='
            \ . escape(fnamemodify(b:salve.root, ':t') . ' repl', ' ')
            \ cmd.args
      if get(get(g:, 'dispatch_last_start', {}), 'handler', 'headless') ==# 'headless'
        return
      endif
    elseif a:background
      echohl WarningMsg
      echomsg "Can't start background console without dispatch.vim"
      echohl None
      return
    elseif has('win32')
      execute '!start '.cmd.args
    else
      execute '!'.cmd.args
      return
    endif
  finally
    execute cd fnameescape(cwd)
  endtry

  let i = 0
  while empty(portfile) && i < 300 && !getchar(0)
    let i += 1
    sleep 100m
    let portfile = s:portfile()
  endwhile
endfunction

function! s:connect(autostart) abort
  if !exists('b:salve') || !exists(':FireplaceConnect')
    return {}
  endif
  let portfile = s:portfile()
  if exists('g:salve_auto_start_repl') && a:autostart && empty(portfile) && exists(':Start') ==# 2
    call s:repl(1, '')
    let portfile = s:portfile()
  endif

  try
    return empty(portfile) ? {} :
          \ fireplace#register_port_file(portfile, b:salve.root)
  catch
    return {}
  endtry
endfunction

function! s:fcall(fn, path, ...) abort
  let ns = matchstr(a:path, '^\a\a\+\ze:')
  if len(ns) && exists('*' . ns . '#' . a:fn)
    return call(ns . '#' . a:fn, [a:path] + a:000)
  else
    return call(a:fn, [a:path] + a:000)
  endif
endfunction

function! s:filereadable(path) abort
  if exists('*ProjectionistHas')
    return call('ProjectionistHas', [a:path])
  else
    return s:fcall('filereadable', a:path)
  endif
endfunction

function! s:detect(file) abort
  if !exists('b:salve')
    let root = a:file
    let previous = ""
    while root !=# previous && root !~# '^\.\=$\|^[\/][\/][^\/]*$'
      if s:filereadable(root . '/project.clj') && join(s:fcall('readfile', root . '/project.clj', '', 50)) =~# '(\s*defproject\%(\s*{{\)\@!'
        let b:salve = {
              \ "local_manifest": root.'/project.clj',
              \ "global_manifest": expand('~/.lein/profiles.clj'),
              \ "root": root,
              \ "compiler": "lein",
              \ "classpath_cmd": "lein -o classpath",
              \ "start_cmd": "lein repl"}
        let b:java_root = root
        break
      elseif s:filereadable(root . '/build.boot')
        let boot_home = len($BOOT_HOME) ? $BOOT_HOME : expand('~/.boot')
        let b:salve = {
              \ "local_manifest": root.'/build.boot',
              \ "global_manifest": boot_home.'/profile.boot',
              \ "root": root,
              \ "compiler": "boot",
              \ "classpath_cmd": "boot show --fake-classpath",
              \ "start_cmd": "boot repl"}
        let b:java_root = root
        break
      elseif s:filereadable(root . '/deps.edn')
        let b:salve = {
              \ "local_manifest": root.'/deps.edn',
              \ "global_manifest": expand('~/.clojure/deps.edn'),
              \ "root": root,
              \ "compiler": "clojure",
              \ "classpath_cmd": "clojure -Spath",
              \ "start_cmd": "clojure -Sdeps " . shellescape(g:salve_edn_deps) . " -m nrepl.cmdline --interactive --middleware " . shellescape(g:salve_edn_middleware)}
        let b:java_root = root
      elseif s:filereadable(root . '/shadow-cljs.edn')
        let b:salve = {
              \ "local_manifest": root . '/shadow-cljs.edn',
              \ "global_manifest": expand('~/.shadow-cljs/config.edn'),
              \ "root": root,
              \ "compiler": "shadowcljs",
              \ "portfiles": [root . "/.shadow-cljs/nrepl.port"],
              \ "classpath_cmd": "npx shadow-cljs classpath",
              \ "start_cmd": "npx shadow-cljs clj-repl"}
      endif
      let previous = root
      let root = fnamemodify(root, ':h')
    endwhile
  endif
  return exists('b:salve')
endfunction

function! s:split(path) abort
  return split(a:path, has('win32') ? ';' : ':')
endfunction

function! s:absolute(path, parent) abort
  if a:path =~# '^/\|^\a\+:'
    return a:path
  else
    return a:parent . (exists('+shellslash') && !&shellslash ? '\' : '/') . a:path
  endif
endfunction

function! s:scrape_path() abort
  let cd = haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  try
    execute cd fnameescape(b:salve.root)
    let path = matchstr(system(b:salve.classpath_cmd), "[^\n]*\\ze\n*$")
    if v:shell_error
      return []
    endif
    return map(s:split(path), 's:absolute(v:val, b:salve.root)')
  catch /^Vim\%((\a\+)\)\=:E472:/
    return []
  finally
    execute cd fnameescape(cwd)
  endtry
endfunction

function! s:eval(conn, code, default) abort
  try
    if has_key(a:conn, 'message') || has_key(a:conn, 'Message')
      let request = {'op': 'eval', 'code': a:code, 'session': '', 'ns': 'user'}
      for msg in has_key(a:conn, 'message') ? a:conn.message(request, type([])) : a:conn.Message(request, type([]))
        if has_key(msg, 'value')
          return msg.value
        endif
      endfor
    endif
  catch
  endtry
  return a:default
endfunction

function! s:my_paths(path) abort
  return map(filter(copy(a:path),
        \ 'strpart(v:val, 0, len(b:salve.root)) ==# b:salve.root'),
        \ 'v:val[strlen(b:salve.root)+1:-1]')
endfunction

function! s:path() abort
  let projts = getftime(b:salve.local_manifest)
  let profts = getftime(b:salve.global_manifest)
  let cache = expand(g:classpath_cache . '/') . substitute(b:salve.root, '[:\/]', '%', 'g')

  let ts = getftime(cache)
  if ts > projts && ts > profts
    let path = split(get(readfile(cache), 0, ''), ',')

  elseif b:salve.compiler !=# 'clojure'
    let conn = s:connect(0)
    let ts = +s:eval(conn, '(.getStartTime (java.lang.management.ManagementFactory/getRuntimeMXBean))', '-2000')[0:-4]
    if ts > projts && ts > profts
      let value = s:eval(conn, '[(System/getProperty "path.separator") (or (System/getProperty "fake.class.path") (System/getProperty "java.class.path") "")]', '')
      if len(value) > 8
        let path = split(eval(value[5:-2]), value[2])
        if empty(s:my_paths(path))
          unlet path
        else
          call writefile([join(path, ',')], cache)
        endif
      endif
    endif
  endif

  if !exists('path')
    let path = s:scrape_path()
    if empty(path)
      let path = map(['test', 'src', 'dev-resources', 'resources'], 'b:salve.root."/".v:val')
    endif
    call writefile([join(path, ',')], cache)
  endif

  return path
endfunction

function! s:activate() abort
  if !exists('b:salve')
    return
  endif
  command! -buffer -bar -bang -nargs=* Console call s:repl(<bang>0, <q-args>)
  execute 'compiler' b:salve.compiler
  let &l:errorformat .= ',%\&' . escape('dir='.b:salve.root, '\,')
  let &l:errorformat .= ',%\&' . escape('classpath='.join(s:path(), ','), '\,')
  if get(b:, 'dispatch') =~# ':RunTests '
    let &l:errorformat .= ',%\&buffer=test ' . matchstr(b:dispatch, ':RunTests \zs.*')
  endif
endfunction

function! s:projectionist_detect() abort
  if !s:detect(get(g:, 'projectionist_file', get(b:, 'projectionist_file', '')))
    return
  endif
  let mypaths = map(filter(copy(s:path()),
        \ 'strpart(v:val, 0, len(b:salve.root)) ==# b:salve.root'),
        \ 'v:val[strlen(b:salve.root)+1:-1]')
  let projections = {}
  let main = []
  let test = []
  let spec = []
  for path in s:my_paths(s:path())
    let projections[path.'/*'] = {'type': 'resource'}
    if path !~# 'target\|resources'
      let projections[path.'/*.clj'] = {'type': 'source', 'template': ['(ns {dot|hyphenate})']}
      let projections[path.'/*.cljc'] = {'type': 'source', 'template': ['(ns {dot|hyphenate})']}
      let projections[path.'/*.java'] = {'type': 'source'}
    endif
    if path =~# 'resource'
    elseif path =~# 'test'
      let test += [path]
    elseif path =~# 'spec'
      let spec += [path]
    elseif path =~# 'src'
      let main += [path]
    endif
  endfor
  call projectionist#append(b:salve.root, projections)
  let projections = {}

  let proj = {'type': 'test', 'alternate': map(copy(main), 'v:val."/{}.clj"') +
        \ map(copy(main), 'v:val."/{}.cljc"')}
  for path in test
    let projections[path.'/*_test.clj'] = proj
    let projections[path.'/*_test.cljc'] = proj
    let projections[path.'/**/test/*.clj'] = proj
    let projections[path.'/**/test/*.cljc'] = proj
    let projections[path.'/**/t_*.clj'] = proj
    let projections[path.'/**/t_*.cljc'] = proj
    let projections[path.'/**/test_*.clj'] = proj
    let projections[path.'/**/test_*.cljc'] = proj
    let projections[path.'/*.clj'] = {'dispatch': ':RunTests {dot|hyphenate}'}
    let projections[path.'/*.cljc'] = {'dispatch': ':RunTests {dot|hyphenate}'}
  endfor
  for path in spec
    let projections[path.'/*_spec.clj'] = proj
    let projections[path.'/*_spec.cljc'] = proj
  endfor

  for path in main
    let proj = {'type': 'main', 'alternate': map(copy(spec), 'v:val."/{}_spec.clj"')}
    let proj = {'type': 'main', 'alternate': map(copy(spec), 'v:val."/{}_spec.cljc"')}
    for tpath in test
      call extend(proj.alternate, [
            \ tpath.'/{}_test.clj',
            \ tpath.'/{}_test.cljc',
            \ tpath.'/{dirname}/test/{basename}.clj',
            \ tpath.'/{dirname}/test/{basename}.cljc',
            \ tpath.'/{dirname}/t_{basename}.clj',
            \ tpath.'/{dirname}/t_{basename}.cljc',
            \ tpath.'/{dirname}/t_{basename}.clj',
            \ tpath.'/{dirname}/t_{basename}.cljc'])
    endfor
    let projections[path.'/*.clj'] = proj
    let projections[path.'/*.cljc'] = proj
  endfor
  call projectionist#append(b:salve.root, projections)
endfunction

augroup salve
  autocmd!
  autocmd User FireplacePreConnect call s:connect(1)
  autocmd FileType clojure
        \ if s:detect(expand('%:p')) |
        \  let &l:path = join(s:path(), ',') |
        \ endif
  autocmd User ProjectionistDetect call s:projectionist_detect()
  autocmd User ProjectionistActivate call s:activate()
  autocmd BufReadPost *
        \ if !exists(':ProjectDo') && s:detect(expand('%:p')) |
        \  call s:activate() |
        \ endif
augroup END
