let s:dbui_instance = {}
let s:dbui = {}

function! db_ui#open(mods) abort
  call s:init()
  return s:dbui_instance.drawer.open(a:mods)
endfunction

function! db_ui#toggle() abort
  call s:init()
  return s:dbui_instance.drawer.toggle()
endfunction

function! db_ui#close() abort
  call s:init()
  return s:dbui_instance.drawer.quit()
endfunction

function! db_ui#save_dbout(file) abort
  call s:init()
  return s:dbui_instance.save_dbout(a:file)
endfunction

function! db_ui#connections_list() abort
  call s:init()
  return map(copy(s:dbui_instance.dbs_list), {_,v-> {
        \ 'name': v.name,
        \ 'url': v.url,
        \ 'is_connected': !empty(s:dbui_instance.dbs[v.key_name].conn),
        \ 'source': v.source,
        \ }})
endfunction

function! db_ui#find_buffer() abort
  call s:init()
  if !len(s:dbui_instance.dbs_list)
    return db_ui#notifications#error('No database entries found in DBUI.')
  endif

  if !exists('b:dbui_db_key_name')
    let saved_query_db = s:dbui_instance.drawer.get_query().get_saved_query_db_name()
    let db = s:get_db(saved_query_db)
    if empty(db)
      return db_ui#notifications#error('No database entries selected or found.')
    endif
    call s:dbui_instance.connect(db)
    call db_ui#notifications#info('Assigned buffer to db '.db.name, {'delay': 10000 })
    let b:dbui_db_key_name = db.key_name
    let b:db = db.conn
  endif

  if !exists('b:dbui_db_key_name')
    return db_ui#notifications#error('Unable to find in DBUI. Not a valid dbui query buffer.')
  endif

  let db = b:dbui_db_key_name
  let bufname = bufname('%')

  call s:dbui_instance.drawer.get_query().setup_buffer(s:dbui_instance.dbs[db], { 'existing_buffer': 1 }, bufname, 0)
  if exists('*vim_dadbod_completion#fetch')
    call vim_dadbod_completion#fetch(bufnr(''))
  endif
  let s:dbui_instance.dbs[db].expanded = 1
  let s:dbui_instance.dbs[db].buffers.expanded = 1
  call s:dbui_instance.drawer.open()
  let row = 1
  for line in s:dbui_instance.drawer.content
    if line.dbui_db_key_name ==? db && line.type ==? 'buffer' && line.file_path ==? bufname
      break
    endif
    let row += 1
  endfor
  call cursor(row, 0)
  call s:dbui_instance.drawer.render({ 'db_key_name': db, 'queries': 1 })
  wincmd p
endfunction

function! db_ui#rename_buffer() abort
  call s:init()
  return s:dbui_instance.drawer.rename_buffer(bufname('%'), get(b:, 'dbui_db_key_name'), 0)
endfunction

function! db_ui#get_conn_info(db_key_name) abort
  if empty(s:dbui_instance)
    return {}
  endif
  if !has_key(s:dbui_instance.dbs, a:db_key_name)
    return {}
  endif
  let db = s:dbui_instance.dbs[a:db_key_name]
  call s:dbui_instance.connect(db)
  return {
        \ 'url': db.url,
        \ 'conn': db.conn,
        \ 'tables': db.tables.list,
        \ 'schemas': db.schemas.list,
        \ 'scheme': db.scheme,
        \ 'connected': !empty(db.conn),
        \ }
endfunction

function! db_ui#query(query) abort
  if empty(b:db)
    throw 'Cannot find valid connection for a buffer.'
  endif

  let parsed = db#url#parse(b:db)
  let scheme = db_ui#schemas#get(parsed.scheme)
  if empty(scheme)
    throw 'Unsupported scheme '.parsed.scheme
  endif

  let result = db_ui#schemas#query(b:db, scheme, a:query)

  return scheme.parse_results(result, 0)
endfunction

function! db_ui#print_last_query_info() abort
  call s:init()
  let info = s:dbui_instance.drawer.get_query().get_last_query_info()
  if empty(info.last_query)
    return db_ui#notifications#info('No queries ran.')
  endif

  let content = ['Last query:'] + info.last_query
  let content += ['' + 'Time: '.info.last_query_time.' sec.']

  return db_ui#notifications#info(content, {'echo': 1})
endfunction

function! db_ui#statusline(...)
  let db_key_name = get(b:, 'dbui_db_key_name', '')
  let dbout = get(b:, 'db', '')
  if empty(s:dbui_instance) || (&filetype !=? 'dbout' && empty(db_key_name))
    return ''
  end
  if &filetype ==? 'dbout'
    let last_query_info = s:dbui_instance.drawer.get_query().get_last_query_info()
    let last_query_time = last_query_info.last_query_time
    if !empty(last_query_time)
      return 'Last query time: '.last_query_time.' sec.'
    endif
    return ''
  endif
  let opts = get(a:, 1, {})
  let prefix = get(opts, 'prefix', 'DBUI: ')
  let separator = get(opts, 'separator', ' -> ')
  let show = get(opts, 'show', ['db_name', 'schema', 'table'])
  let db_table = get(b:, 'dbui_table_name', '')
  let db_schema = get(b:, 'dbui_schema_name', '')
  let db = s:dbui_instance.dbs[db_key_name]
  let data = { 'db_name': db.name, 'schema': db_schema, 'table': db_table }
  let content = []
  for item in show
    let entry = get(data, item, '')
    if !empty(entry)
      call add(content, entry)
    endif
  endfor
  return prefix.join(content, separator)
endfunction

function! s:dbui.new() abort
  let instance = copy(self)
  let instance.dbs = {}
  let instance.dbs_list = []
  let instance.save_path = ''
  let instance.connections_path = ''
  let instance.tmp_location = ''
  let instance.drawer = {}
  let instance.old_buffers = []
  let instance.dbout_list = {}

  if !empty(g:db_ui_save_location)
    let instance.save_path = substitute(fnamemodify(g:db_ui_save_location, ':p'), '\/$', '', '')
    let instance.connections_path = printf('%s/%s', instance.save_path, 'connections.json')
  endif

  if !empty(g:db_ui_tmp_query_location)
    let tmp_loc = substitute(fnamemodify(g:db_ui_tmp_query_location, ':p'), '\/$', '', '')
    if !isdirectory(tmp_loc)
      call mkdir(tmp_loc, 'p')
    endif
    let instance.tmp_location = tmp_loc
    let instance.old_buffers = glob(tmp_loc.'/*', 1, 1)
  endif

  call instance.populate_dbs()
  let instance.drawer = db_ui#drawer#new(instance)
  return instance
endfunction

function! s:dbui.save_dbout(file) abort
  let db_input = ''
  let content = ''
  if has_key(self.dbout_list, a:file) && !empty(self.dbout_list[a:file])
    return
  endif
  let db_input = get(getbufvar(a:file, 'db', {}), 'input')
  if !empty(db_input) && filereadable(db_input)
    let content = get(readfile(db_input, 1), 0)
    if len(content) > 30
      let content = printf('%s...', content[0:30])
    endif
  endif
  let self.dbout_list[a:file] = content
  call self.drawer.render()
endfunction

function! s:dbui.populate_dbs() abort
  let self.dbs_list = []
  call self.populate_from_dotenv()
  call self.populate_from_env()
  call self.populate_from_global_variable()
  call self.populate_from_connections_file()

  for db in self.dbs_list
    let key_name = printf('%s_%s', db.name, db.source)
    if !has_key(self.dbs, key_name) || db.url !=? self.dbs[key_name].url
      let new_entry = self.generate_new_db_entry(db)
      if !empty(new_entry)
        let self.dbs[key_name] = new_entry
      endif
    else
      let self.dbs[key_name] = self.drawer.populate(self.dbs[key_name])
    endif
  endfor
endfunction

function! s:dbui.generate_new_db_entry(db) abort
  let parsed_url = self.parse_url(a:db.url)
  if empty(parsed_url)
    return parsed_url
  endif
  let db_name = substitute(get(parsed_url, 'path', ''), '^\/', '', '')
  let save_path = ''
  if !empty(self.save_path)
    let save_path = printf('%s/%s', self.save_path, a:db.name)
  endif
  let buffers = filter(copy(self.old_buffers), 'fnamemodify(v:val, ":e") =~? "^".a:db.name."-" || fnamemodify(v:val, ":t") =~? "^".a:db.name."-"')

  let db = {
        \ 'url': a:db.url,
        \ 'conn': '',
        \ 'conn_error': '',
        \ 'conn_tried': 0,
        \ 'source': a:db.source,
        \ 'scheme': '',
        \ 'table_helpers': {},
        \ 'expanded': 0,
        \ 'tables': {'expanded': 0 , 'items': {}, 'list': [] },
        \ 'schemas': {'expanded': 0, 'items': {}, 'list': [] },
        \ 'saved_queries': { 'expanded': 0, 'list': [] },
        \ 'buffers': { 'expanded': 0, 'list': buffers, 'tmp': [] },
        \ 'save_path': save_path,
        \ 'db_name': !empty(db_name) ? db_name : a:db.name,
        \ 'name': a:db.name,
        \ 'key_name': printf('%s_%s', a:db.name, a:db.source),
        \ 'schema_support': 0,
        \ 'quote': 0,
        \ 'default_scheme': '',
        \ 'filetype': '',
        \ 'is_server': 0,
        \ 'databases': {'expanded': 0, 'items': {}, 'list': []},
        \ }

  call self.populate_schema_info(db)

  " Check if this is a server-level connection
  if self.is_server_connection(db)
    let db.is_server = 1
  endif

  " Add SSMS-style object types structure for database-level connections when SSMS mode is enabled
  if g:db_ui_use_ssms_style && !get(db, 'is_server', 0)
    let db.object_types = {
          \ 'views': {'expanded': 0, 'items': {}, 'list': []},
          \ 'procedures': {'expanded': 0, 'items': {}, 'list': []},
          \ 'functions': {'expanded': 0, 'items': {}, 'list': []},
          \ }
  endif

  return db
endfunction

function! s:dbui.resolve_url_global_variable(Value) abort
  if type(a:Value) ==? type('')
    return a:Value
  endif

  if type(a:Value) ==? type(function('tr'))
    return call(a:Value, [])
  endif

  " if type(a:Value) ==? type(v:t_func)
  " endif
  "
  " echom string(type(a:Value))
  " echom string(a:Value)
  "
  throw 'Invalid type global variable database url:'..type(a:Value)
endfunction

function! s:dbui.populate_from_global_variable() abort
  if exists('g:db') && !empty(g:db)
    let url = self.resolve_url_global_variable(g:db)
    let gdb_name = split(url, '/')[-1]
    call self.add_if_not_exists(gdb_name, url, 'g:dbs')
  endif

  if !exists('g:dbs') || empty(g:dbs)
    return self
  endif

  if type(g:dbs) ==? type({})
    for [db_name, Db_url] in items(g:dbs)
      call self.add_if_not_exists(db_name, self.resolve_url_global_variable(Db_url), 'g:dbs')
    endfor
    return self
  endif

  for db in g:dbs
    call self.add_if_not_exists(db.name, self.resolve_url_global_variable(db.url), 'g:dbs')
  endfor

  return self
endfunction

function! s:dbui.populate_from_dotenv() abort
  let prefix = g:db_ui_dotenv_variable_prefix
  let all_envs = {}
  if exists('*environ')
    let all_envs = environ()
  else
    for item in systemlist('env')
      let env = split(item, '=')
      if len(env) > 1
        let all_envs[env[0]] = join(env[1:], '')
      endif
    endfor
  endif
  let all_envs = extend(all_envs, exists('*DotenvGet') ? DotenvGet() : {})
  for [name, url] in items(all_envs)
    if stridx(name, prefix) != -1
      let db_name = tolower(join(split(name, prefix)))
      call self.add_if_not_exists(db_name, url, 'dotenv')
    endif
  endfor
endfunction

function! s:dbui.env(var) abort
  return exists('*DotenvGet') ? DotenvGet(a:var) : eval('$'.a:var)
endfunction

function! s:dbui.populate_from_env() abort
  let env_url = self.env(g:db_ui_env_variable_url)
  if empty(env_url)
    return self
  endif
  let env_name = self.env(g:db_ui_env_variable_name)
  if empty(env_name)
    let env_name = get(split(env_url, '/'), -1, '')
  endif

  if empty(env_name)
    return db_ui#notifications#error(
          \ printf('Found %s variable for db url, but unable to parse the name. Please provide name via %s', g:db_ui_env_variable_url, g:db_ui_env_variable_name))
  endif

  call self.add_if_not_exists(env_name, env_url, 'env')
  return self
endfunction

function! s:dbui.parse_url(url) abort
  try
    return db#url#parse(a:url)
  catch /.*/
    call db_ui#notifications#error(v:exception)
    return {}
  endtry
endfunction

" SSMS-style connection helper functions
function! s:dbui.parse_connection_level(url) abort
  let parsed = self.parse_url(a:url)
  if empty(parsed)
    return { 'level': 'unknown', 'has_database': 0, 'database': '' }
  endif

  let path = get(parsed, 'path', '/')
  let db_name = substitute(path, '^\/', '', '')
  let has_database = !empty(db_name) && db_name !=? '/'

  return {
        \ 'level': has_database ? 'database' : 'server',
        \ 'has_database': has_database ? 1 : 0,
        \ 'database': db_name
        \ }
endfunction

function! s:dbui.is_server_connection(db) abort
  if !g:db_ui_use_ssms_style
    return 0
  endif
  let conn_level = self.parse_connection_level(a:db.url)
  return conn_level.level ==? 'server'
endfunction

function! s:dbui.get_database_from_url(url) abort
  let conn_level = self.parse_connection_level(a:url)
  return conn_level.database
endfunction

function! s:dbui.build_database_url(server_url, database_name) abort
  let parsed = self.parse_url(a:server_url)
  if empty(parsed)
    return ''
  endif

  " Remove trailing slash if present
  let base_url = substitute(a:server_url, '\/$', '', '')
  " Add database name
  return base_url . '/' . a:database_name
endfunction

function! s:dbui.populate_from_connections_file() abort
  if empty(self.connections_path) || !filereadable(self.connections_path)
    return
  endif

  let file = db_ui#utils#readfile(self.connections_path)

  for conn in file
    call self.add_if_not_exists(conn.name, conn.url, 'file')
  endfor

  return self
endfunction

function! s:dbui.add_if_not_exists(name, url, source) abort
  let existing = get(filter(copy(self.dbs_list), 'v:val.name ==? a:name && v:val.source ==? a:source'), 0, {})
  if !empty(existing)
    return db_ui#notifications#warning(printf('Warning: Duplicate connection name "%s" in "%s" source. First one added has precedence.', a:name, a:source))
  endif
  return add(self.dbs_list, {
        \ 'name': a:name, 'url': db_ui#resolve(a:url), 'source': a:source, 'key_name': printf('%s_%s', a:name, a:source)
        \ })
endfunction

function! s:dbui.is_tmp_location_buffer(db, buf) abort
  if index(a:db.buffers.tmp, a:buf) > -1
    return 1
  endif
  return !empty(self.tmp_location) && a:buf =~? '^'.self.tmp_location
endfunction

function! s:dbui.connect(db) abort
  if !empty(a:db.conn)
    return a:db
  endif

  " For server-level connections in SSMS mode, we don't need a real db connection
  " We'll connect to individual databases when they're expanded
  if get(a:db, 'is_server', 0) && g:db_ui_use_ssms_style
    try
      let query_time = reltime()
      call db_ui#notifications#info('Preparing server connection for '.a:db.name.'...')
      " Populate schema info from the URL (without actual connection)
      call self.populate_schema_info(a:db)
      " Set a special marker to indicate server is ready
      let a:db.conn = a:db.url
      let a:db.conn_error = ''
      call db_ui#notifications#info('Server connection prepared for '.a:db.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
    catch /.*/
      let a:db.conn_error = v:exception
      let a:db.conn = ''
      call db_ui#notifications#error('Error preparing server connection for '.a:db.name.': '.v:exception, {'width': 80 })
    endtry
    let a:db.conn_tried = 1
    return a:db
  endif

  try
    let query_time = reltime()
    call db_ui#notifications#info('Connecting to db '.a:db.name.'...')
    let a:db.conn = db#connect(a:db.url)
    let a:db.conn_error = ''
    call self.populate_schema_info(a:db)
    call db_ui#notifications#info('Connected to db '.a:db.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  catch /.*/
    let a:db.conn_error = v:exception
    let a:db.conn = ''
    call db_ui#notifications#error('Error connecting to db '.a:db.name.': '.v:exception, {'width': 80 })
  endtry

  redraw!
  let a:db.conn_tried = 1
  return a:db
endfunction

function! s:dbui.populate_schema_info(db) abort
  let url = !empty(a:db.conn) ? a:db.conn : a:db.url
  let parsed_url = self.parse_url(url)
  let scheme = get(parsed_url, 'scheme', '')
  let scheme_info = db_ui#schemas#get(scheme)
  let a:db.scheme = scheme
  let a:db.table_helpers = db_ui#table_helpers#get(scheme)
  let a:db.schema_support = db_ui#schemas#supports_schemes(scheme_info, parsed_url)
  let a:db.quote = get(scheme_info, 'quote', 0)
  let a:db.default_scheme = get(scheme_info, 'default_scheme', '')
  let a:db.filetype = get(scheme_info, 'filetype', db#adapter#call(url, 'input_extension', [], 'sql'))
  " Properly map mongodb js to javascript
  if a:db.filetype ==? 'js'
    let a:db.filetype = 'javascript'
  endif
endfunction

" SSMS-style server and database population functions
function! s:dbui.create_database_structure(server, db_name) abort
  let db_url = self.build_database_url(a:server.url, a:db_name)
  let save_path = ''
  if !empty(a:server.save_path)
    let save_path = printf('%s/%s', a:server.save_path, a:db_name)
  endif

  let database = {
        \ 'name': a:db_name,
        \ 'url': db_url,
        \ 'conn': '',
        \ 'conn_error': '',
        \ 'conn_tried': 0,
        \ 'expanded': 0,
        \ 'scheme': a:server.scheme,
        \ 'quote': a:server.quote,
        \ 'default_scheme': a:server.default_scheme,
        \ 'filetype': a:server.filetype,
        \ 'save_path': save_path,
        \ 'object_types': {
        \   'tables': {'expanded': 0, 'items': {}, 'list': []},
        \   'views': {'expanded': 0, 'items': {}, 'list': []},
        \   'procedures': {'expanded': 0, 'items': {}, 'list': []},
        \   'functions': {'expanded': 0, 'items': {}, 'list': []},
        \ },
        \ 'schemas': {'expanded': 0, 'items': {}, 'list': []},
        \ 'tables': {'expanded': 0, 'items': {}, 'list': []},
        \ }

  return database
endfunction

function! s:dbui.populate_databases(server) abort
  if !a:server.is_server || !g:db_ui_use_ssms_style
    return
  endif

  let scheme_info = db_ui#schemas#get(a:server.scheme)
  if !db_ui#schemas#supports_databases(scheme_info)
    return
  endif

  try
    let query_time = reltime()
    call db_ui#notifications#info('Fetching databases from '.a:server.name.'...')

    " For server-level queries, we need to connect to a system database
    " Create a temporary connection with the appropriate system database
    let system_db = self.get_system_database_for_listing(a:server.scheme)
    let temp_url = self.build_database_url(a:server.url, system_db)
    let temp_conn = db#connect(temp_url)

    " Create a temporary db object for the query
    let temp_db = {'conn': temp_conn, 'scheme': a:server.scheme}
    let result = db_ui#schemas#query_databases(temp_db, scheme_info)
    let parsed_result = get(scheme_info, 'parse_results', {results, min -> results})(result, 1)

    let a:server.databases.list = []
    for row in parsed_result
      let db_name = type(row) ==? type([]) ? get(row, 0, '') : row
      let db_name = trim(db_name)
      if empty(db_name)
        continue
      endif

      " Filter system databases if configured
      if g:db_ui_hide_system_databases && self.is_system_database(a:server.scheme, db_name)
        continue
      endif

      call add(a:server.databases.list, db_name)
      if !has_key(a:server.databases.items, db_name)
        let a:server.databases.items[db_name] = self.create_database_structure(a:server, db_name)
      endif
    endfor

    call db_ui#notifications#info('Found '.len(a:server.databases.list).' databases on '.a:server.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  catch /.*/
    call db_ui#notifications#error('Error fetching databases: '.v:exception)
  endtry
endfunction

function! s:dbui.get_system_database_for_listing(scheme) abort
  " Returns the default system database to connect to for listing databases
  let default_dbs = {
        \ 'sqlserver': 'master',
        \ 'postgresql': 'postgres',
        \ 'mysql': 'information_schema',
        \ 'mariadb': 'information_schema',
        \ }
  return get(default_dbs, a:scheme, 'master')
endfunction

function! s:dbui.is_system_database(scheme, db_name) abort
  let system_dbs = {
        \ 'sqlserver': ['master', 'model', 'msdb', 'tempdb'],
        \ 'postgresql': ['template0', 'template1', 'postgres'],
        \ 'mysql': ['information_schema', 'mysql', 'performance_schema', 'sys'],
        \ 'mariadb': ['information_schema', 'mysql', 'performance_schema', 'sys'],
        \ }

  let scheme_system_dbs = get(system_dbs, a:scheme, [])
  return index(scheme_system_dbs, a:db_name) >= 0
endfunction

function! s:dbui.connect_to_database(server, db_name) abort
  if !has_key(a:server.databases.items, a:db_name)
    return {}
  endif

  let database = a:server.databases.items[a:db_name]
  if !empty(database.conn)
    return database
  endif

  try
    let query_time = reltime()
    call db_ui#notifications#info('Connecting to database '.a:db_name.'...')
    let database.conn = db#connect(database.url)
    let database.conn_error = ''
    call db_ui#notifications#info('Connected to '.a:db_name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  catch /.*/
    let database.conn_error = v:exception
    let database.conn = ''
    call db_ui#notifications#error('Error connecting to '.a:db_name.': '.v:exception)
  endtry

  let database.conn_tried = 1
  return database
endfunction

function! s:dbui.populate_object_types(database) abort
  if !g:db_ui_use_ssms_style
    return
  endif

  let scheme_info = db_ui#schemas#get(a:database.scheme)
  let object_types = g:db_ui_ssms_object_types

  for object_type in object_types
    if object_type ==? 'tables'
      " Tables are handled by existing populate_tables logic
      continue
    endif

    if !a:database.object_types[object_type].expanded
      continue
    endif

    call self.populate_object_type(a:database, object_type, scheme_info)
  endfor
endfunction

function! s:dbui.populate_object_type(database, object_type, scheme_info) abort
  let query_func = 'query_' . a:object_type
  if !exists('*db_ui#schemas#' . query_func)
    return
  endif

  try
    let query_time = reltime()
    call db_ui#notifications#info('Fetching '.a:object_type.' from '.a:database.name.'...')
    let result = call('db_ui#schemas#' . query_func, [a:database, a:scheme_info])
    let parsed_result = get(a:scheme_info, 'parse_results', {results, min -> results})(result, 2)

    let a:database.object_types[a:object_type].list = []
    let a:database.object_types[a:object_type].items = {}

    for row in parsed_result
      if type(row) ==? type([]) && len(row) >= 2
        let schema_name = trim(row[0])
        let object_name = trim(row[1])

        " Skip header rows (column names)
        if schema_name =~? '^\(TABLE_SCHEMA\|table_schema\|schema_name\|routine_schema\)$'
          continue
        endif
      else
        let schema_name = a:database.default_scheme
        let object_name = trim(row)
      endif

      if empty(object_name)
        continue
      endif

      let full_name = g:db_ui_show_schema_prefix && !empty(schema_name)
            \ ? '['.schema_name.'].['.object_name.']'
            \ : object_name

      call add(a:database.object_types[a:object_type].list, full_name)
      let a:database.object_types[a:object_type].items[full_name] = {
            \ 'schema': schema_name,
            \ 'name': object_name,
            \ 'full_name': full_name,
            \ 'expanded': 0,
            \ 'structural_groups': {
            \   'columns': {'expanded': 0, 'data': []},
            \   'indexes': {'expanded': 0, 'data': []},
            \   'keys': {'expanded': 0, 'data': []},
            \   'primary_keys': {'expanded': 0, 'data': []},
            \   'foreign_keys': {'expanded': 0, 'data': []},
            \   'constraints': {'expanded': 0, 'data': []},
            \   'parameters': {'expanded': 0, 'data': []},
            \ },
            \ }
    endfor

    " Sort by schema then object name
    call sort(a:database.object_types[a:object_type].list)

    call db_ui#notifications#info('Found '.len(a:database.object_types[a:object_type].list).' '.a:object_type.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  catch /.*/
    call db_ui#notifications#error('Error fetching '.a:object_type.': '.v:exception)
  endtry
endfunction

" Populate structural information for objects (columns, indexes, keys, constraints, parameters)
function! s:dbui.populate_structural_group(database, schema, object_name, group_type) abort
  let scheme_info = db_ui#schemas#get(a:database.scheme)

  try
    let query_time = reltime()
    call db_ui#notifications#info('Fetching '.a:group_type.' for '.a:object_name.'...')

    let result = []
    let min_columns = 1

    if a:group_type ==# 'columns'
      let result = db_ui#schemas#query_columns(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 5  " column_name, data_type, max_length, nullable, default
    elseif a:group_type ==# 'indexes'
      let result = db_ui#schemas#query_indexes(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 2  " index_name, type (and possibly more)
    elseif a:group_type ==# 'primary_keys'
      let result = db_ui#schemas#query_primary_keys(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 2
    elseif a:group_type ==# 'foreign_keys'
      let result = db_ui#schemas#query_foreign_keys(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 2
    elseif a:group_type ==# 'constraints'
      let result = db_ui#schemas#query_constraints(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 2  " constraint_name, type
    elseif a:group_type ==# 'parameters'
      let result = db_ui#schemas#query_parameters(a:database, scheme_info, a:schema, a:object_name)
      let min_columns = 3  " param_name, data_type, mode
    endif

    let parsed_result = get(scheme_info, 'parse_results', {results, min -> results})(result, min_columns)
    call db_ui#notifications#info('Found '.len(parsed_result).' '.a:group_type.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')

    return parsed_result
  catch /.*/
    call db_ui#notifications#error('Error fetching '.a:group_type.': '.v:exception)
    return []
  endtry
endfunction

" Resolve only urls for DBs that are files
function db_ui#resolve(url) abort
  let parsed_url = db#url#parse(a:url)
  let resolve_schemes = ['sqlite', 'jq', 'duckdb', 'osquery']

  if index(resolve_schemes, get(parsed_url, 'scheme', '')) > -1
    return db#resolve(a:url)
  endif

  return a:url
endfunction

function! db_ui#reset_state() abort
  let s:dbui_instance = {}
endfunction

function! s:init() abort
  if empty(s:dbui_instance)
    let s:dbui_instance = s:dbui.new()
  endif

  return s:dbui_instance
endfunction

function! s:get_db(saved_query_db) abort
  if !len(s:dbui_instance.dbs_list)
    return {}
  endif

  if !empty(a:saved_query_db)
    let saved_db = get(filter(copy(s:dbui_instance.dbs_list), 'v:val.name ==? a:saved_query_db'), 0, {})
    if empty(saved_db)
      return {}
    endif
    return s:dbui_instance.dbs[saved_db.key_name]
  endif

  if len(s:dbui_instance.dbs_list) ==? 1
    return values(s:dbui_instance.dbs)[0]
  endif

  let options = map(copy(s:dbui_instance.dbs_list), '(v:key + 1).") ".v:val.name')
  let selection = db_ui#utils#inputlist(['Select db to assign this buffer to:'] + options)
  if selection < 1 || selection > len(options)
    call db_ui#notifications#error('Wrong selection.')
    return {}
  endif
  let selected_db = s:dbui_instance.dbs_list[selection - 1]
  let selected_db = s:dbui_instance.dbs[selected_db.key_name]
  return selected_db
endfunction
