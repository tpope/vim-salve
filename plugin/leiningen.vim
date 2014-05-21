" Location: plugin/leiningen.vim
" Author:   Tim Pope <http://tpo.pe/>

if exists('g:loaded_leiningen')
  finish
endif
let g:loaded_leiningen = 1

if !exists('g:classpath_cache')
  let g:classpath_cache = '~/.cache/vim/classpath'
endif

if !isdirectory(expand(g:classpath_cache))
  call mkdir(expand(g:classpath_cache), 'p')
endif

function! s:portfile() abort
  if !exists('b:leiningen_root')
    return ''
  endif

  let root = b:leiningen_root
  let portfiles = [root.'/.nrepl-port', root.'/target/repl-port', root.'/target/repl/repl-port']

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
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  try
    execute cd fnameescape(b:leiningen_root)
    if exists(':Start') == 2
      execute 'Start'.(a:background ? '!' : '') '-title='
            \ . escape(fnamemodify(b:leiningen_root, ':t') . ' repl', ' ')
            \ 'lein repl'.args
      if get(get(g:, 'dispatch_last_start', {}), 'handler', 'headless') ==# 'headless'
        return
      endif
    elseif a:background
      echohl WarningMsg
      echomsg "Can't start background console without dispatch.vim"
      echohl None
      return
    elseif has('win32')
      execute '!start lein repl'.args
    else
      execute '!lein repl'.args
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
  if !exists('b:leiningen_root') || !exists(':FireplaceConnect')
    return {}
  endif
  let portfile = s:portfile()
  if a:autostart && empty(portfile) && exists(':Start') ==# 2
    call s:repl(1, '')
    let portfile = s:portfile()
  endif

  return empty(portfile) ? {} :
        \ fireplace#register_port_file(portfile, b:leiningen_root)
endfunction

function! s:detect(file) abort
  if !exists('b:leiningen_root')
    let root = simplify(fnamemodify(a:file, ':p:s?[\/]$??'))
    if !isdirectory(fnamemodify(root, ':h'))
      return ''
    endif
    let previous = ""
    while root !=# previous
      if filereadable(root . '/project.clj') && join(readfile(root . '/project.clj', '', 50)) =~# '(\s*defproject'
        let b:leiningen_root = root
        let b:java_root = root
        break
      endif
      let previous = root
      let root = fnamemodify(root, ':h')
    endwhile
  endif
  return exists('b:leiningen_root')
endfunction

function! s:split(path) abort
  return split(a:path, has('win32') ? ';' : ':')
endfunction

function! s:scrape_path(root) abort
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  try
    execute cd fnameescape(a:root)
    let path = matchstr(system('lein -o classpath'), "[^\n]*\\ze\n*$")
    if v:shell_error
      return []
    endif
    return s:split(path)
  finally
    execute cd fnameescape(cwd)
  endtry
endfunction

function! s:path() abort
  let conn = s:connect(0)

  let projts = getftime(b:leiningen_root.'/project.clj')
  let profts = getftime(expand('~/.lein/profiles.clj'))
  let cache = expand(g:classpath_cache . '/') . substitute(b:leiningen_root, '[:\/]', '%', 'g')

  let ts = getftime(cache)
  if ts > projts && ts > profts
    let path = split(get(readfile(cache), 0, ''), ',')

  elseif has_key(conn, 'path')
    let ts = +get(conn.eval('(.getStartTime (java.lang.management.ManagementFactory/getRuntimeMXBean))', {'session': ''}), 'value', '-2000')[0:-4]
    if ts > projts && ts > profts
      let response = conn.eval(
            \ '[(System/getProperty "path.separator") (System/getProperty "java.class.path")]',
            \ {'session': ''})
      let path = split(eval(response.value[-1][5:-2]), response.value[-1][2])
      call writefile([join(path, ',')], cache)
    endif
  endif

  if !exists('path')
    let path = s:scrape_path(b:leiningen_root)
    if empty(path)
      let path = map(['test', 'src', 'dev-resources', 'resources'], 'b:leiningen_root."/".v:val')
    endif
    call writefile([join(path, ',')], cache)
  endif

  return path
endfunction

function! s:activate() abort
  if !exists('b:leiningen_root')
    return
  endif
  command! -bar -bang -nargs=* Console call s:repl(<bang>0, <q-args>)
  compiler lein
  let &l:errorformat .= ',' . escape('chdir '.b:leiningen_root, '\,')
  let &l:errorformat .= ',' . escape('classpath,'.join(s:path()), '\,')
endfunction

function! s:projectionist_detect() abort
  if !s:detect(get(g:, 'projectionist_file', get(b:, 'projectionist_file', '')))
    return
  endif
  let mypaths = map(filter(copy(s:path()),
        \ 'strpart(v:val, 0, len(b:leiningen_root)) ==# b:leiningen_root'),
        \ 'v:val[strlen(b:leiningen_root)+1:-1]')
  let projections = {}
  let main = []
  let test = []
  let spec = []
  for path in mypaths
    let projections[path.'/*'] = {'type': 'resource'}
    if path !~# 'target\|resources'
      let projections[path.'/*.clj'] = {'type': 'source', 'template': ['(ns {dot|hyphenate})']}
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
  let projections['*'] = {'start': 'lein run'}
  call projectionist#append(b:leiningen_root, projections)
  let projections = {}
  for path in test
    let proj = {'type': 'test', 'alternate': map(copy(main), 'v:val."/{}.clj"')}
    let projections[path.'/*_test.clj'] = proj
    let projections[path.'/**/test/*.clj'] = proj
    let projections[path.'/**/t_*.clj'] = proj
    let projections[path.'/**/test_*.clj'] = proj
    let projections[path.'/*.clj'] = {'dispatch': ':RunTests {dot|hyphenate}'}
  endfor
  for path in main
    let proj = {'type': 'main', 'alternate': map(copy(spec), 'v:val."/{}_spec.clj"')}
    for tpath in test
      call extend(proj.alternate, [
            \ tpath.'/{}_test.clj',
            \ tpath.'/{dirname}/test/{basename}.clj',
            \ tpath.'/{dirname}/t_{basename}.clj',
            \ tpath.'/{dirname}/t_{basename}.clj'])
    endfor
    let projections[path.'/*.clj'] = proj
  endfor
  call projectionist#append(b:leiningen_root, projections)
endfunction

augroup leiningen
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
