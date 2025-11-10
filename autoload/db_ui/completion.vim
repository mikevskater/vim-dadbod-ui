" ==============================================================================
" Completion Cache System for SSMS-like IntelliSense
" ==============================================================================
" This module provides a TTL-based caching system for database metadata to
" enable fast, context-aware SQL completions similar to SSMS IntelliSense.
"
" Architecture:
" - Per-database metadata caches (tables, views, procedures, functions, columns)
" - External database reference detection and caching
" - Query context parsing for smart completions
" - Integration with vim-dadbod-completion and blink.cmp
" ==============================================================================

let s:completion_cache = {}
let s:debug_enabled = 0

" ==============================================================================
" DBUI Cache Access (Unified Cache Architecture)
" ==============================================================================
" Instead of duplicating data, we read directly from DBUI tree cache.
" This ensures tree expansion and IntelliSense share the same data.

" Get DBUI instance for accessing tree cache
" @return DBUI instance dictionary
function! s:get_dbui_instance() abort
  try
    let drawer = db_ui#drawer#get()
    if empty(drawer) || !has_key(drawer, 'dbui')
      return {}
    endif
    return drawer.dbui
  catch
    call s:debug('Failed to get DBUI instance: ' . v:exception)
    return {}
  endtry
endfunction

" Get database entry from DBUI cache
" @param db_key_name - Database identifier
" @return Database dictionary from DBUI cache
function! s:get_dbui_database(db_key_name) abort
  let dbui = s:get_dbui_instance()
  if empty(dbui) || !has_key(dbui, 'dbs')
    return {}
  endif
  if !has_key(dbui.dbs, a:db_key_name)
    return {}
  endif
  return dbui.dbs[a:db_key_name]
endfunction

" Get tables from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of table objects
function! s:get_tables_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  " If external DB specified, navigate to that database
  if !empty(external_db) && has_key(db, 'databases')
    " Server-level connection - get external database
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    " Current database
    let target_db = db
  endif

  " Get tables from object_types if SSMS mode, otherwise from tables
  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'tables')
    return get(target_db.object_types.tables, 'list', [])
  else
    return get(target_db.tables, 'list', [])
  endif
endfunction

" Get views from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of view objects
function! s:get_views_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  if !empty(external_db) && has_key(db, 'databases')
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    let target_db = db
  endif

  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'views')
    return get(target_db.object_types.views, 'list', [])
  else
    return []
  endif
endfunction

" Get procedures from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of procedure objects
function! s:get_procedures_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  if !empty(external_db) && has_key(db, 'databases')
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    let target_db = db
  endif

  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'procedures')
    return get(target_db.object_types.procedures, 'list', [])
  else
    return []
  endif
endfunction

" Get functions from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of function objects
function! s:get_functions_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  if !empty(external_db) && has_key(db, 'databases')
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    let target_db = db
  endif

  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'functions')
    return get(target_db.object_types.functions, 'list', [])
  else
    return []
  endif
endfunction

" Get schemas from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of schema names
function! s:get_schemas_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  if !empty(external_db) && has_key(db, 'databases')
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    let target_db = db
  endif

  return get(target_db.schemas, 'list', [])
endfunction

" Get databases from DBUI cache (server-level connections only)
" @param db_key_name - Server identifier
" @return List of database names
function! s:get_databases_from_dbui(db_key_name) abort
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db) || !has_key(db, 'databases')
    return []
  endif
  return get(db.databases, 'list', [])
endfunction

" ==============================================================================
" Granular Lazy Loading (Unified with DBUI Tree)
" ==============================================================================

" Ensure external database objects are loaded (granular loading)
" This triggers DBUI's populate functions, ensuring tree and IntelliSense share cache
" @param db_key_name - Server identifier
" @param db_name - External database name
" @param object_type - 'tables'|'views'|'procedures'|'functions'
" @return 1 if loaded or already available, 0 if failed
function! db_ui#completion#ensure_external_db_objects(db_key_name, db_name, object_type) abort
  if !get(g:, 'db_ui_intellisense_lazy_load', 1)
    return 0
  endif

  let db = s:get_dbui_database(a:db_key_name)
  if empty(db) || !has_key(db, 'databases')
    call s:debug('Not a server-level connection: ' . a:db_key_name)
    return 0
  endif

  " Check if database structure exists
  if !has_key(db.databases.items, a:db_name)
    call s:debug('Database not in server list: ' . a:db_name)
    return 0
  endif

  let target_db = db.databases.items[a:db_name]

  " Connect to database if not connected
  if empty(target_db.conn) && !target_db.conn_tried
    call s:debug('Connecting to external database: ' . a:db_name)
    let dbui = s:get_dbui_instance()
    if !empty(dbui)
      call dbui.connect_to_database(db, a:db_name)
    endif
  endif

  " Check if object type already loaded
  if has_key(target_db.object_types, a:object_type)
    let obj_cache = target_db.object_types[a:object_type]
    if obj_cache.expanded && !empty(obj_cache.list)
      call s:debug('Objects already loaded: ' . a:db_name . '.' . a:object_type)
      return 1
    endif
  endif

  " Trigger loading via DBUI drawer
  call s:debug('Triggering granular load: ' . a:db_name . '.' . a:object_type)

  if get(g:, 'db_ui_show_loading_indicator', 1)
    call db_ui#notifications#info('Loading ' . a:db_name . ' ' . a:object_type . '...')
  endif

  try
    let drawer = db_ui#drawer#get()
    if empty(drawer)
      call s:debug('DBUI drawer not available')
      return 0
    endif

    if a:object_type ==# 'tables'
      call drawer.populate_tables(target_db)
    else
      let dbui = s:get_dbui_instance()
      if !empty(dbui)
        let scheme_info = db_ui#schemas#get(target_db.scheme)
        call dbui.populate_object_type(target_db, a:object_type, scheme_info)
      endif
    endif

    " Mark as expanded so we don't re-fetch
    let target_db.object_types[a:object_type].expanded = 1

    call s:debug('Successfully loaded: ' . a:db_name . '.' . a:object_type . ' (' . len(target_db.object_types[a:object_type].list) . ' items)')
    return 1
  catch
    call s:debug('Error loading objects: ' . v:exception)
    return 0
  endtry
endfunction

" Check if a schema exists in an external database
" @param db_key_name - Server identifier
" @param db_name - External database name
" @param schema_name - Schema name to check
" @return 1 if schema exists, 0 otherwise
function! s:is_schema_in_external_db(db_key_name, db_name, schema_name) abort
  let schemas = s:get_schemas_from_dbui(a:db_key_name, a:db_name)
  for schema in schemas
    let schema_val = type(schema) == type({}) ? get(schema, 'name', schema) : schema
    if schema_val ==? a:schema_name
      return 1
    endif
  endfor
  return 0
endfunction

" Check if a table exists in an external database schema
" @param db_key_name - Server identifier
" @param db_name - External database name
" @param schema_name - Schema name
" @param table_name - Table name to check
" @return 1 if table exists, 0 otherwise
function! s:is_table_in_external_db(db_key_name, db_name, schema_name, table_name) abort
  let tables = s:get_tables_from_dbui(a:db_key_name, a:db_name)
  for table in tables
    if type(table) == type({})
      let tbl_name = get(table, 'name', '')
      let tbl_schema = get(table, 'schema', '')
      if tbl_name ==? a:table_name && tbl_schema ==? a:schema_name
        return 1
      endif
    else
      " String format: [schema].[table]
      let full_name = '[' . a:schema_name . '].[' . a:table_name . ']'
      if table ==? full_name
        return 1
      endif
    endif
  endfor
  return 0
endfunction

" ==============================================================================
" Cache Management
" ==============================================================================

" Initialize completion cache for a database connection
" @param db_key_name - Unique database identifier (from b:dbui_db_key_name)
" @return void
function! db_ui#completion#init_cache(db_key_name) abort
  if !get(g:, 'db_ui_enable_intellisense', 1)
    return
  endif

  call s:debug('init_cache called for: ' . a:db_key_name)

  " Skip if cache already exists and is valid
  if s:is_cache_valid(a:db_key_name)
    call s:debug('Cache already valid for: ' . a:db_key_name)
    return
  endif

  " Initialize empty cache structure
  let s:completion_cache[a:db_key_name] = {
        \ 'databases': [],
        \ 'schemas': [],
        \ 'tables': [],
        \ 'views': [],
        \ 'procedures': [],
        \ 'functions': [],
        \ 'columns_by_table': {},
        \ 'external_databases': {},
        \ 'last_updated': localtime(),
        \ 'ttl': get(g:, 'db_ui_intellisense_cache_ttl', 300),
        \ 'loading': 0
        \ }

  call s:debug('Cache initialized for: ' . a:db_key_name)

  " Trigger async metadata fetch
  call s:fetch_metadata_async(a:db_key_name)
endfunction

" Check if cache exists and is within TTL
" @param db_key_name - Database identifier
" @return 1 if valid, 0 otherwise
function! s:is_cache_valid(db_key_name) abort
  if !has_key(s:completion_cache, a:db_key_name)
    return 0
  endif

  let cache = s:completion_cache[a:db_key_name]
  let current_time = localtime()
  let age = current_time - cache.last_updated

  return age < cache.ttl
endfunction

" Refresh cache for a specific database
" @param db_key_name - Database identifier
" @return void
function! db_ui#completion#refresh_cache(db_key_name) abort
  call s:debug('refresh_cache called for: ' . a:db_key_name)

  if empty(a:db_key_name)
    call db_ui#notifications#error('No database connection found in current buffer')
    return
  endif

  " Remove existing cache
  if has_key(s:completion_cache, a:db_key_name)
    unlet s:completion_cache[a:db_key_name]
  endif

  " Reinitialize
  call db_ui#completion#init_cache(a:db_key_name)
  call db_ui#notifications#info('Completion cache refreshed for: ' . a:db_key_name)
endfunction

" Clear all completion caches
" @return void
function! db_ui#completion#clear_all_caches() abort
  let cache_count = len(s:completion_cache)
  let s:completion_cache = {}
  call db_ui#notifications#info('Cleared ' . cache_count . ' completion cache(s)')
endfunction

" Clear cache for a specific database
" @param db_key_name - Database identifier
" @return void
function! db_ui#completion#clear_cache_for(db_key_name) abort
  if has_key(s:completion_cache, a:db_key_name)
    unlet s:completion_cache[a:db_key_name]
    call db_ui#notifications#info('Cache cleared for: ' . a:db_key_name)
  else
    call db_ui#notifications#warning('No cache found for: ' . a:db_key_name)
  endif
endfunction

" ==============================================================================
" Metadata Fetching
" ==============================================================================

" Fetch metadata asynchronously
" @param db_key_name - Database identifier
" @return void
function! s:fetch_metadata_async(db_key_name) abort
  " Check if dbui instance exists
  if !exists('*db_ui#get_conn_info')
    call s:debug('db_ui#get_conn_info not available')
    return
  endif

  let db_info = db_ui#get_conn_info(a:db_key_name)
  if empty(db_info)
    call s:debug('No db_info found for: ' . a:db_key_name)
    return
  endif

  call s:debug('Fetching metadata for: ' . a:db_key_name)

  " Mark as loading
  if has_key(s:completion_cache, a:db_key_name)
    let s:completion_cache[a:db_key_name].loading = 1
  endif

  " Show loading indicator if enabled
  if get(g:, 'db_ui_show_loading_indicator', 1)
    call db_ui#notifications#info('Loading completion metadata for ' . a:db_key_name . '...')
  endif

  " Fetch metadata using existing db_ui functions
  " These already have caching built-in from schemas.vim
  try
    " Get scheme info for this database type
    let scheme_info = {}
    if exists('*db_ui#schemas#get') && has_key(db_info, 'scheme')
      let scheme_info = db_ui#schemas#get(db_info.scheme)
    endif

    " Get database list (for server-level connections)
    if exists('*db_ui#schemas#query_databases') && !empty(scheme_info)
      let databases = db_ui#schemas#query_databases(db_info, scheme_info)
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].databases = databases
      endif
    endif

    " Get schemas (if supported by database type)
    let schemas = get(db_info, 'schemas', [])
    if has_key(s:completion_cache, a:db_key_name)
      let s:completion_cache[a:db_key_name].schemas = schemas
    endif

    " Get tables using query function (not from DBUI cache)
    if exists('*db_ui#schemas#query_tables') && !empty(scheme_info)
      let tables = db_ui#schemas#query_tables(db_info, scheme_info)
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].tables = tables
      endif
      call s:debug('Fetched and cached ' . len(tables) . ' tables')
    else
      " Fallback to DBUI cache if query function not available
      let tables = get(db_info, 'tables', [])
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].tables = tables
      endif
      call s:debug('Using DBUI cache: ' . len(tables) . ' tables')
    endif

    " Get views (if enabled)
    if exists('*db_ui#schemas#query_views') && get(g:, 'db_ui_use_postgres_views', 1) && !empty(scheme_info)
      let views = db_ui#schemas#query_views(db_info, scheme_info)
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].views = views
      endif
      call s:debug('Fetched and cached ' . len(views) . ' views')
    endif

    " Get procedures (if supported)
    if exists('*db_ui#schemas#query_procedures') && !empty(scheme_info)
      let procedures = db_ui#schemas#query_procedures(db_info, scheme_info)
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].procedures = procedures
      endif
      call s:debug('Fetched and cached ' . len(procedures) . ' procedures')
    endif

    " Get functions (if supported)
    if exists('*db_ui#schemas#query_functions') && !empty(scheme_info)
      let functions = db_ui#schemas#query_functions(db_info, scheme_info)
      if has_key(s:completion_cache, a:db_key_name)
        let s:completion_cache[a:db_key_name].functions = functions
      endif
      call s:debug('Fetched and cached ' . len(functions) . ' functions')
    endif

    " Update last_updated timestamp and mark as loaded
    if has_key(s:completion_cache, a:db_key_name)
      let s:completion_cache[a:db_key_name].last_updated = localtime()
      let s:completion_cache[a:db_key_name].loading = 0
    endif

    call s:debug('Metadata fetch complete for: ' . a:db_key_name)

    if get(g:, 'db_ui_show_loading_indicator', 1)
      call db_ui#notifications#info('Completion metadata loaded for ' . a:db_key_name)
    endif
  catch
    call s:debug('Error fetching metadata: ' . v:exception)
    if has_key(s:completion_cache, a:db_key_name)
      let s:completion_cache[a:db_key_name].loading = 0
    endif
    call db_ui#notifications#error('Failed to load completion metadata: ' . v:exception)
  endtry
endfunction

" ==============================================================================
" Completion Retrieval
" ==============================================================================

" Get completions for a specific object type
" @param db_key_name - Database identifier
" @param object_type - Type of objects to retrieve ('tables', 'views', 'procedures', 'functions', 'schemas', 'databases', 'columns')
" @param filter - Optional filter string (table name for columns)
" @return List of completion items
function! db_ui#completion#get_completions(db_key_name, object_type, ...) abort
  let filter = get(a:, 1, '')

  call s:debug('get_completions called: db=' . a:db_key_name . ', type=' . a:object_type . ', filter=' . filter)

  " Initialize cache if needed
  if !has_key(s:completion_cache, a:db_key_name)
    call db_ui#completion#init_cache(a:db_key_name)
  endif

  let cache = s:completion_cache[a:db_key_name]

  " If cache is loading, return empty (async fetch in progress)
  if cache.loading
    call s:debug('Cache is loading, returning empty')
    return []
  endif

  " Handle different object types
  if a:object_type ==? 'columns'
    return s:get_columns(a:db_key_name, filter)
  elseif a:object_type ==? 'tables'
    return s:format_completions(cache.tables, 'table')
  elseif a:object_type ==? 'views'
    return s:format_completions(cache.views, 'view')
  elseif a:object_type ==? 'procedures'
    return s:format_completions(cache.procedures, 'procedure')
  elseif a:object_type ==? 'functions'
    return s:format_completions(cache.functions, 'function')
  elseif a:object_type ==? 'schemas'
    return s:format_completions(cache.schemas, 'schema')
  elseif a:object_type ==? 'databases'
    return s:format_completions(cache.databases, 'database')
  elseif a:object_type ==? 'all_objects'
    " Return all tables, views, procedures, functions
    let all_items = []
    call extend(all_items, s:format_completions(cache.tables, 'table'))
    call extend(all_items, s:format_completions(cache.views, 'view'))
    call extend(all_items, s:format_completions(cache.procedures, 'procedure'))
    call extend(all_items, s:format_completions(cache.functions, 'function'))
    return all_items
  else
    call s:debug('Unknown object type: ' . a:object_type)
    return []
  endif
endfunction

" Get completions from an external database
" @param db_key_name - Current database key
" @param external_db_name - External database name
" @param object_type - Type of objects to retrieve
" @param filter - Optional filter
" @return List of completion items
function! db_ui#completion#get_external_completions(db_key_name, external_db_name, object_type, ...) abort
  let filter = get(a:, 1, '')

  " Ensure external database is cached
  call db_ui#completion#fetch_external_database(a:db_key_name, a:external_db_name)

  if !has_key(s:completion_cache, a:db_key_name)
    return []
  endif

  let server_cache = s:completion_cache[a:db_key_name]

  if !has_key(server_cache.external_databases, a:external_db_name)
    return []
  endif

  let ext_cache = server_cache.external_databases[a:external_db_name]

  " If still loading, return empty
  if get(ext_cache, 'loading', 0)
    return []
  endif

  " Return requested object type
  if a:object_type ==? 'tables'
    return s:format_completions(ext_cache.tables, 'table')
  elseif a:object_type ==? 'views'
    return s:format_completions(ext_cache.views, 'view')
  elseif a:object_type ==? 'procedures'
    return s:format_completions(ext_cache.procedures, 'procedure')
  elseif a:object_type ==? 'functions'
    return s:format_completions(ext_cache.functions, 'function')
  elseif a:object_type ==? 'all_objects'
    let all_items = []
    call extend(all_items, s:format_completions(ext_cache.tables, 'table'))
    call extend(all_items, s:format_completions(ext_cache.views, 'view'))
    call extend(all_items, s:format_completions(ext_cache.procedures, 'procedure'))
    call extend(all_items, s:format_completions(ext_cache.functions, 'function'))
    return all_items
  else
    return []
  endif
endfunction

" Get columns for a specific table
" @param db_key_name - Database identifier
" @param table_name - Table name to get columns for
" @return List of column completion items
function! s:get_columns(db_key_name, table_name) abort
  if empty(a:table_name)
    call s:debug('No table name provided for columns')
    return []
  endif

  let cache = s:completion_cache[a:db_key_name]

  " Check if columns are already cached for this table
  if has_key(cache.columns_by_table, a:table_name)
    call s:debug('Returning cached columns for: ' . a:table_name)
    return cache.columns_by_table[a:table_name]
  endif

  " Fetch columns from database
  call s:debug('Fetching columns for table: ' . a:table_name)

  if !exists('*db_ui#get_conn_info')
    return []
  endif

  let db_info = db_ui#get_conn_info(a:db_key_name)
  if empty(db_info)
    return []
  endif

  try
    if exists('*db_ui#schemas#query_columns')
      " Get scheme info
      let scheme_info = {}
      if exists('*db_ui#schemas#get') && has_key(db_info, 'scheme')
        let scheme_info = db_ui#schemas#get(db_info.scheme)
      endif

      if empty(scheme_info)
        call s:debug('No scheme info available for: ' . db_info.scheme)
        return []
      endif

      " Parse table name for schema.table format
      let schema = ''
      let table = a:table_name
      if a:table_name =~# '\.'
        let parts = split(a:table_name, '\.')
        if len(parts) == 2
          let schema = parts[0]
          let table = parts[1]
        elseif len(parts) > 2
          " Handle database.schema.table - take last 2 parts
          let schema = parts[-2]
          let table = parts[-1]
        endif
      endif

      let raw_columns = db_ui#schemas#query_columns(db_info, scheme_info, schema, table)
      let formatted_columns = s:format_columns(raw_columns)

      " Cache the columns
      let cache.columns_by_table[a:table_name] = formatted_columns

      call s:debug('Fetched and cached ' . len(formatted_columns) . ' columns for: ' . a:table_name)
      return formatted_columns
    endif
  catch
    call s:debug('Error fetching columns: ' . v:exception)
  endtry

  return []
endfunction

" ==============================================================================
" External Database Handling
" ==============================================================================

" Ensure external database is cached (lazy loading)
" Checks if external DB is cached, triggers fetch if not
" @param server_db_key - The current database connection key
" @param db_name - Name of the external database
" @return 1 if cached (or fetch successful), 0 otherwise
function! db_ui#completion#ensure_external_db_cached(server_db_key, db_name) abort
  if !get(g:, 'db_ui_intellisense_fetch_external_db', 1)
    return 0
  endif

  if !has_key(s:completion_cache, a:server_db_key)
    return 0
  endif

  let server_cache = s:completion_cache[a:server_db_key]

  " Check if already cached and valid
  if has_key(server_cache.external_databases, a:db_name)
    if s:is_external_db_cache_valid(a:server_db_key, a:db_name)
      call s:debug('External DB already cached: ' . a:db_name)
      return 1
    endif
  endif

  " Not cached or expired - trigger fetch
  call s:debug('Live-loading external DB: ' . a:db_name)

  " Show user feedback (async fetch)
  if get(g:, 'db_ui_show_loading_indicator', 1)
    call db_ui#notifications#info('Loading ' . a:db_name . ' metadata...')
  endif

  " Trigger async fetch
  return db_ui#completion#fetch_external_database(a:server_db_key, a:db_name)
endfunction

" Fetch metadata for an external database referenced in a query
" @param server_db_key - The current database connection key
" @param db_name - Name of the external database
" @return 1 if successful, 0 otherwise
function! db_ui#completion#fetch_external_database(server_db_key, db_name) abort
  if !get(g:, 'db_ui_intellisense_fetch_external_db', 1)
    call s:debug('External database fetching is disabled')
    return 0
  endif

  call s:debug('fetch_external_database: server=' . a:server_db_key . ', db=' . a:db_name)

  " Check if server cache exists
  if !has_key(s:completion_cache, a:server_db_key)
    call s:debug('No cache found for server: ' . a:server_db_key)
    return 0
  endif

  let server_cache = s:completion_cache[a:server_db_key]

  " Check if external database is already cached
  if has_key(server_cache.external_databases, a:db_name)
    if s:is_external_db_cache_valid(a:server_db_key, a:db_name)
      call s:debug('External database cache is valid: ' . a:db_name)
      return 1
    endif
  endif

  " Initialize external database cache
  let server_cache.external_databases[a:db_name] = {
        \ 'schemas': [],
        \ 'tables': [],
        \ 'views': [],
        \ 'procedures': [],
        \ 'functions': [],
        \ 'columns_by_table': {},
        \ 'last_updated': localtime(),
        \ 'loading': 1
        \ }

  call s:debug('Initialized external database cache for: ' . a:db_name)

  " Fetch metadata for external database
  try
    " Get current database connection info
    let server_info = db_ui#get_conn_info(a:server_db_key)
    if empty(server_info)
      call s:debug('No connection info for server: ' . a:server_db_key)
      let server_cache.external_databases[a:db_name].loading = 0
      return 0
    endif

    " Build connection URL for external database
    " Parse the server URL and replace database name
    let ext_url = s:build_external_db_url(server_info.url, a:db_name)
    if empty(ext_url)
      call s:debug('Failed to build external database URL')
      let server_cache.external_databases[a:db_name].loading = 0
      return 0
    endif

    call s:debug('External database URL: ' . ext_url)

    " Create temporary connection
    let ext_conn = db#connect(ext_url)
    if empty(ext_conn)
      call s:debug('Failed to connect to external database: ' . a:db_name)
      let server_cache.external_databases[a:db_name].loading = 0
      return 0
    endif

    " Create temporary db info structure
    let ext_db_info = {
          \ 'url': ext_url,
          \ 'conn': ext_conn,
          \ 'scheme': server_info.scheme,
          \ 'name': a:db_name
          \ }

    " Fetch metadata using existing functions
    if exists('*db_ui#schemas#query_tables')
      let tables = db_ui#schemas#query_tables(ext_db_info)
      let server_cache.external_databases[a:db_name].tables = tables
      call s:debug('Fetched ' . len(tables) . ' tables from external DB: ' . a:db_name)
    endif

    if exists('*db_ui#schemas#query_views') && get(g:, 'db_ui_use_postgres_views', 1)
      let views = db_ui#schemas#query_views(ext_db_info)
      let server_cache.external_databases[a:db_name].views = views
      call s:debug('Fetched ' . len(views) . ' views from external DB: ' . a:db_name)
    endif

    if exists('*db_ui#schemas#query_procedures')
      let procedures = db_ui#schemas#query_procedures(ext_db_info)
      let server_cache.external_databases[a:db_name].procedures = procedures
      call s:debug('Fetched ' . len(procedures) . ' procedures from external DB: ' . a:db_name)
    endif

    if exists('*db_ui#schemas#query_functions')
      let functions = db_ui#schemas#query_functions(ext_db_info)
      let server_cache.external_databases[a:db_name].functions = functions
      call s:debug('Fetched ' . len(functions) . ' functions from external DB: ' . a:db_name)
    endif

    " Mark as successfully loaded
    let server_cache.external_databases[a:db_name].loading = 0
    let server_cache.external_databases[a:db_name].last_updated = localtime()

    call s:debug('Successfully fetched metadata for external DB: ' . a:db_name)
    return 1

  catch
    call s:debug('Error fetching external database metadata: ' . v:exception)
    if has_key(server_cache.external_databases, a:db_name)
      let server_cache.external_databases[a:db_name].loading = 0
    endif
    return 0
  endtry
endfunction

" Build connection URL for an external database
" @param base_url - Base connection URL (from current database)
" @param db_name - External database name
" @return Connection URL for external database
function! s:build_external_db_url(base_url, db_name) abort
  if empty(a:base_url) || empty(a:db_name)
    return ''
  endif

  " Parse the URL using vim-dadbod's parser
  let parsed = db#url#parse(a:base_url)
  if empty(parsed)
    return ''
  endif

  " Replace the database name in the URL
  let scheme = parsed.scheme
  let host = get(parsed, 'host', 'localhost')
  let port = get(parsed, 'port', '')
  let user = get(parsed, 'user', '')
  let password = get(parsed, 'password', '')

  " Build new URL with external database name
  let new_url = scheme . '://'

  " Add authentication if present
  if !empty(user)
    let new_url .= user
    if !empty(password)
      let new_url .= ':' . password
    endif
    let new_url .= '@'
  endif

  " Add host
  let new_url .= host

  " Add port if specified
  if !empty(port)
    let new_url .= ':' . port
  endif

  " Add database name
  let new_url .= '/' . a:db_name

  return new_url
endfunction

" Check if external database is on the same server
" @param server_db_key - Server database key
" @param db_name - Database name to check
" @return 1 if on same server, 0 otherwise
function! db_ui#completion#is_database_on_server(server_db_key, db_name) abort
  if !has_key(s:completion_cache, a:server_db_key)
    return 0
  endif

  let cache = s:completion_cache[a:server_db_key]

  " Check if database exists in the server's database list
  for db in cache.databases
    if type(db) == v:t_string && db ==? a:db_name
      return 1
    elseif type(db) == v:t_dict && get(db, 'name', '') ==? a:db_name
      return 1
    endif
  endfor

  return 0
endfunction

" Check if external database cache is valid
" @param server_db_key - Server database key
" @param db_name - External database name
" @return 1 if valid, 0 otherwise
function! s:is_external_db_cache_valid(server_db_key, db_name) abort
  if !has_key(s:completion_cache, a:server_db_key)
    return 0
  endif

  let server_cache = s:completion_cache[a:server_db_key]
  if !has_key(server_cache.external_databases, a:db_name)
    return 0
  endif

  let ext_cache = server_cache.external_databases[a:db_name]
  let current_time = localtime()
  let age = current_time - ext_cache.last_updated
  let ttl = get(g:, 'db_ui_intellisense_cache_ttl', 300)

  return age < ttl
endfunction

" ==============================================================================
" Query Context Parsing (Phase 2 - Enhanced)
" ==============================================================================

" Get cursor context for completion
" @param bufnr - Buffer number
" @param line_text - Current line text (may be partial for multi-line)
" @param col - Cursor column
" @return Dictionary with context information
function! db_ui#completion#get_cursor_context(bufnr, line_text, col) abort
  let context = {
        \ 'type': 'unknown',
        \ 'database': '',
        \ 'schema': '',
        \ 'table': '',
        \ 'alias': '',
        \ 'qualifier': '',
        \ 'aliases': {},
        \ 'external_databases': []
        \ }

  " Get full query text for multi-line support
  let query_text = s:get_query_text_before_cursor(a:bufnr, a:col)

  " Get text before cursor on current line
  let before_cursor = strpart(a:line_text, 0, a:col - 1)

  call s:debug('get_cursor_context: before_cursor="' . before_cursor . '"')

  " Parse aliases from entire query
  let context.aliases = s:parse_table_aliases(query_text)
  call s:debug('Parsed aliases: ' . string(context.aliases))

  " Parse external database references
  let context.external_databases = db_ui#completion#parse_database_references(query_text)

  " Detect completion type based on text before cursor
  let context = s:detect_completion_type(before_cursor, context)

  return context
endfunction

" Get query text before cursor (multi-line support)
" @param bufnr - Buffer number
" @param col - Current column
" @return String with all query text up to cursor
function! s:get_query_text_before_cursor(bufnr, col) abort
  let current_line = line('.')
  let lines = getbufline(a:bufnr, 1, current_line)

  " Truncate last line to cursor position
  if len(lines) > 0
    let lines[-1] = strpart(lines[-1], 0, a:col - 1)
  endif

  return join(lines, ' ')
endfunction

" Detect completion type from text before cursor
" @param before_cursor - Text before cursor
" @param context - Context dictionary to populate
" @return Updated context dictionary
function! s:detect_completion_type(before_cursor, context) abort
  let context = a:context

  " Clean up whitespace for pattern matching
  let text = substitute(a:before_cursor, '\s\+', ' ', 'g')

  " ====================
  " Schema/Table Completions (Use hierarchical resolution)
  " ====================

  " Pattern: word.word.word... - Use hierarchical resolution to determine context
  " This checks in order: DB -> Schema -> Table to intelligently determine what to suggest

  " Check for 3-part identifiers: word1.word2.word3
  if text =~# '\w\+\.\w\+\.\w\+$'
    let matched = matchstr(text, '\w\+\.\w\+\.\w\+$')
    let parts = split(matched, '\.')
    let has_trailing = !empty(parts[-1]) && text !~# '\s$'

    " Get db_key_name from buffer
    let db_key_name = get(b:, 'dbui_db_key_name', '')
    if !empty(db_key_name)
      " Check if first part is a database - if so, auto-fetch if not cached
      if s:is_database(db_key_name, parts[0])
        " This is an external database reference - trigger fetch if needed
        call db_ui#completion#ensure_external_db_cached(db_key_name, parts[0])
      endif

      let resolved = s:resolve_hierarchical_context(db_key_name, parts, has_trailing)
      if resolved.type !=# 'unknown'
        let context.type = resolved.type
        let context.database = resolved.database
        let context.schema = resolved.schema
        let context.table = resolved.table
        return context
      endif
    endif

    " Fallback if hierarchical resolution fails
    if len(parts) == 3 && !s:is_sql_keyword(parts[0])
      let context.type = 'table'
      let context.database = parts[0]
      let context.schema = parts[1]
      call s:debug('Fallback: db.schema.table pattern')
      return context
    endif
  endif

  " Check for 2-part identifiers: word1.word2
  if text =~# '\w\+\.\w\+$' && text !~# '\w\+\.\w\+\.\w\+$'
    let matched = matchstr(text, '\w\+\.\w\+$')
    let parts = split(matched, '\.')
    let has_trailing = !empty(parts[-1]) && text !~# '\s$'

    " Get db_key_name from buffer
    let db_key_name = get(b:, 'dbui_db_key_name', '')
    if !empty(db_key_name)
      " Check if first part is a database - if so, auto-fetch if not cached
      if s:is_database(db_key_name, parts[0])
        " This is an external database reference - trigger fetch if needed
        call db_ui#completion#ensure_external_db_cached(db_key_name, parts[0])
      endif

      let resolved = s:resolve_hierarchical_context(db_key_name, parts, has_trailing)
      if resolved.type !=# 'unknown'
        let context.type = resolved.type
        let context.database = resolved.database
        let context.schema = resolved.schema
        let context.table = resolved.table
        return context
      endif
    endif

    " Fallback if hierarchical resolution fails
    if len(parts) == 2 && !s:is_sql_keyword(parts[0])
      let context.type = 'table'
      let context.schema = parts[0]
      call s:debug('Fallback: schema.table pattern')
      return context
    endif
  endif

  " Pattern: word.| - single word followed by dot
  if text =~# '\w\+\.\s*$' && text !~# '\w\+\.\w\+\.'
    let word = matchstr(text, '\w\+\ze\.\s*$')
    if !s:is_sql_keyword(word)
      " Get db_key_name from buffer
      let db_key_name = get(b:, 'dbui_db_key_name', '')
      if !empty(db_key_name)
        " Check hierarchically what this word refers to
        if s:is_database(db_key_name, word)
          let context.type = 'schema'
          let context.database = word
          call s:debug('Hierarchical: ' . word . ' is database, showing schemas')
          return context
        elseif s:is_schema(db_key_name, word)
          let context.type = 'table'
          let context.schema = word
          call s:debug('Hierarchical: ' . word . ' is schema, showing tables')
          return context
        elseif s:is_table(db_key_name, word)
          let context.type = 'column'
          let context.table = word
          call s:debug('Hierarchical: ' . word . ' is table, showing columns')
          return context
        endif
      endif

      " Fallback: check if alias
      if has_key(context.aliases, word)
        let context.type = 'column'
        let context.table = context.aliases[word].table
        let context.schema = get(context.aliases[word], 'schema', '')
        let context.database = get(context.aliases[word], 'database', '')
        let context.alias = word
        call s:debug('Column completion for alias: ' . word)
        return context
      endif

      " Last fallback: assume it's a table name for column completion
      let context.type = 'column'
      let context.table = word
      call s:debug('Fallback: assuming table for column completion')
      return context
    endif
  endif

  " ====================
  " Keyword-based Detection
  " ====================
  " Note: Dot patterns (word.word) are now handled by hierarchical resolution above

  " After FROM, JOIN - suggest tables/views
  if text =~# '\<\%(FROM\|JOIN\|INTO\)\s\+$'
    let context.type = 'table'
    call s:debug('Table context after FROM/JOIN/INTO')
    return context
  endif

  " After USE - suggest databases
  if text =~# '\<USE\s\+$'
    let context.type = 'database'
    call s:debug('Database context after USE')
    return context
  endif

  " After EXEC/EXECUTE - suggest procedures
  if text =~# '\<\%(EXEC\|EXECUTE\)\s\+$'
    let context.type = 'procedure'
    call s:debug('Procedure context after EXEC')
    return context
  endif

  " Procedure parameter: @parameter_name
  if text =~# '@\w*$'
    let context.type = 'parameter'
    let proc_name = s:get_current_procedure_name(text)
    if !empty(proc_name)
      let context.table = proc_name
      call s:debug('Parameter context for procedure: ' . proc_name)
    endif
    return context
  endif

  " In SELECT list after comma
  if text =~# '\<SELECT\s\+.*,\s*$'
    let context.type = 'column_or_function'
    call s:debug('Column/function context in SELECT list')
    return context
  endif

  " In WHERE/ON clause
  if text =~# '\<\%(WHERE\|ON\|AND\|OR\|HAVING\)\s\+$'
    let context.type = 'column_or_function'
    call s:debug('Column/function context in WHERE/ON')
    return context
  endif

  " In ORDER BY clause
  if text =~# '\<ORDER\s\+BY\s\+$'
    let context.type = 'column'
    call s:debug('Column context in ORDER BY')
    return context
  endif

  " In GROUP BY clause
  if text =~# '\<GROUP\s\+BY\s\+$'
    let context.type = 'column'
    call s:debug('Column context in GROUP BY')
    return context
  endif

  " ====================
  " Default
  " ====================

  " Default: suggest all objects
  let context.type = 'all_objects'
  call s:debug('Default context: all objects')
  return context
endfunction

" Parse table aliases from query
" @param query_text - SQL query text
" @return Dictionary mapping alias -> table info
function! s:parse_table_aliases(query_text) abort
  let aliases = {}

  " Pattern: FROM/JOIN table_spec [AS] alias
  " Supports:
  " - FROM Users u
  " - FROM Users AS u
  " - FROM dbo.Users u
  " - FROM MyDB.dbo.Users u
  " - JOIN Orders o ON ...
  let pattern = '\c\%(FROM\|JOIN\)\s\+\(%((\w+)\.)?%((\w+)\.)?(\w+)\)\s\+\%(AS\s\+\)\?(\w+)'

  let pos = 0
  while 1
    let match_pos = match(a:query_text, pattern, pos)
    if match_pos == -1
      break
    endif

    let matched_text = matchstr(a:query_text, pattern, pos)

    " Parse the full table specification and alias
    " Example matches:
    " "FROM MyDB.dbo.Users u"
    " "FROM dbo.Users AS u"
    " "FROM Users u"
    let parts = split(matched_text, '\s\+')

    if len(parts) >= 2
      let table_spec = parts[1]  " The table specification (may include db.schema.table)
      let alias = parts[-1]      " The alias (last part)

      " Skip if alias is a SQL keyword
      if s:is_sql_keyword(alias) || alias ==# 'AS'
        let pos = match_pos + 1
        continue
      endif

      " Parse table specification
      let spec_parts = split(table_spec, '\.')
      let table_info = {
            \ 'table': spec_parts[-1],
            \ 'schema': len(spec_parts) >= 2 ? spec_parts[-2] : '',
            \ 'database': len(spec_parts) >= 3 ? spec_parts[-3] : '',
            \ 'full_name': table_spec
            \ }

      let aliases[alias] = table_info
      call s:debug('Parsed alias: ' . alias . ' -> ' . string(table_info))
    endif

    let pos = match_pos + len(matched_text)
  endwhile

  return aliases
endfunction

" Check if identifier is a known database
" @param db_key_name - Current database connection
" @param identifier - Name to check
" @return 1 if database exists, 0 otherwise
function! s:is_database(db_key_name, identifier) abort
  " Try unified cache first (DBUI tree)
  let databases = s:get_databases_from_dbui(a:db_key_name)
  for db in databases
    let db_name = type(db) == type({}) ? get(db, 'name', db) : db
    if db_name ==? a:identifier
      return 1
    endif
  endfor

  " Fallback to completion cache if DBUI not available
  if has_key(s:completion_cache, a:db_key_name)
    let cache = s:completion_cache[a:db_key_name]
    for db in cache.databases
      let db_name = type(db) == type({}) ? get(db, 'name', db) : db
      if db_name ==? a:identifier
        return 1
      endif
    endfor
  endif

  return 0
endfunction

" Check if identifier is a known schema
" @param db_key_name - Current database connection
" @param identifier - Name to check
" @return 1 if schema exists, 0 otherwise
function! s:is_schema(db_key_name, identifier) abort
  " Try unified cache first (DBUI tree)
  let schemas = s:get_schemas_from_dbui(a:db_key_name)
  for schema in schemas
    let schema_name = type(schema) == type({}) ? get(schema, 'name', schema) : schema
    if schema_name ==? a:identifier
      return 1
    endif
  endfor

  " Fallback to completion cache if DBUI not available
  if has_key(s:completion_cache, a:db_key_name)
    let cache = s:completion_cache[a:db_key_name]
    for schema in cache.schemas
      let schema_name = type(schema) == type({}) ? get(schema, 'name', schema) : schema
      if schema_name ==? a:identifier
        return 1
      endif
    endfor
  endif

  return 0
endfunction

" Check if identifier is a known table or view
" @param db_key_name - Current database connection
" @param identifier - Name to check
" @param schema - Optional schema to filter by
" @return 1 if table/view exists, 0 otherwise
function! s:is_table(db_key_name, identifier, ...) abort
  let schema_filter = get(a:, 1, '')

  " Try unified cache first (DBUI tree)
  let tables = s:get_tables_from_dbui(a:db_key_name)
  for table in tables
    if type(table) == type({})
      let table_name = get(table, 'name', '')
      let table_schema = get(table, 'schema', '')
      if table_name ==? a:identifier
        if empty(schema_filter) || table_schema ==? schema_filter
          return 1
        endif
      endif
    else
      " String format: check if it matches (could be [schema].[table] or just table)
      if table ==? a:identifier
        return 1
      endif
      " Check if it's [schema].[table] format and matches
      if !empty(schema_filter)
        let full_name = '[' . schema_filter . '].[' . a:identifier . ']'
        if table ==? full_name
          return 1
        endif
      endif
    endif
  endfor

  " Check views too
  let views = s:get_views_from_dbui(a:db_key_name)
  for view in views
    if type(view) == type({})
      let view_name = get(view, 'name', '')
      let view_schema = get(view, 'schema', '')
      if view_name ==? a:identifier
        if empty(schema_filter) || view_schema ==? schema_filter
          return 1
        endif
      endif
    else
      if view ==? a:identifier
        return 1
      endif
      if !empty(schema_filter)
        let full_name = '[' . schema_filter . '].[' . a:identifier . ']'
        if view ==? full_name
          return 1
        endif
      endif
    endif
  endfor

  " Fallback to completion cache if DBUI not available
  if has_key(s:completion_cache, a:db_key_name)
    let cache = s:completion_cache[a:db_key_name]

    for table in cache.tables
      if type(table) == type({})
        let table_name = get(table, 'name', '')
        let table_schema = get(table, 'schema', '')
        if table_name ==? a:identifier
          if empty(schema_filter) || table_schema ==? schema_filter
            return 1
          endif
        endif
      elseif a:identifier ==? table
        return 1
      endif
    endfor

    for view in cache.views
      if type(view) == type({})
        let view_name = get(view, 'name', '')
        let view_schema = get(view, 'schema', '')
        if view_name ==? a:identifier
          if empty(schema_filter) || view_schema ==? schema_filter
            return 1
          endif
        endif
      elseif a:identifier ==? view
        return 1
      endif
    endfor
  endif

  return 0
endfunction

" Resolve hierarchical context for word.word or word.word.word patterns
" Checks in order: DB -> Schema -> Table to determine what each identifier refers to
" @param db_key_name - Current database connection
" @param parts - Array of identifier parts [word1, word2, ...]
" @param has_trailing_content - True if there's text after the last dot (not just dot)
" @return Context dictionary with type and relevant fields
function! s:resolve_hierarchical_context(db_key_name, parts, has_trailing_content) abort
  let context = {'type': 'unknown', 'database': '', 'schema': '', 'table': ''}
  let num_parts = len(a:parts)

  if num_parts == 1
    " Single word - could be partial table name in default schema
    " This is handled elsewhere (keyword-based detection)
    return context
  endif

  if num_parts == 2
    " word1.word2 - Check hierarchically:
    " 1. Is word1 a database? → If yes and trailing content, suggest schemas. If no content after dot, show schemas
    " 2. Is word1 a schema? → If yes and trailing content, suggest tables. If no content, show columns for word2
    " 3. Otherwise → assume schema.table for column completion

    if s:is_database(a:db_key_name, a:parts[0])
      " word1 is a database
      if a:has_trailing_content
        " database.sch → suggest schemas from that database
        let context.type = 'schema'
        let context.database = a:parts[0]
        call s:debug('Hierarchical: ' . a:parts[0] . ' is database, suggesting schemas')
      else
        " database. → suggest schemas
        let context.type = 'schema'
        let context.database = a:parts[0]
        call s:debug('Hierarchical: ' . a:parts[0] . ' is database, showing schemas')
      endif
    elseif s:is_schema(a:db_key_name, a:parts[0])
      " word1 is a schema
      if a:has_trailing_content
        " schema.tab → suggest tables from that schema
        let context.type = 'table'
        let context.schema = a:parts[0]
        call s:debug('Hierarchical: ' . a:parts[0] . ' is schema, suggesting tables')
      else
        " schema.table. → word2 should be a table, show columns
        if s:is_table(a:db_key_name, a:parts[1], a:parts[0])
          let context.type = 'column'
          let context.schema = a:parts[0]
          let context.table = a:parts[1]
          call s:debug('Hierarchical: ' . a:parts[1] . ' is table in schema ' . a:parts[0] . ', showing columns')
        else
          " word2 not a known table, treat as partial table name
          let context.type = 'table'
          let context.schema = a:parts[0]
          call s:debug('Hierarchical: ' . a:parts[1] . ' not found, suggesting tables in schema ' . a:parts[0])
        endif
      endif
    elseif s:is_table(a:db_key_name, a:parts[0])
      " word1 is a table (no schema prefix)
      if !a:has_trailing_content
        " table. → show columns
        let context.type = 'column'
        let context.table = a:parts[0]
        call s:debug('Hierarchical: ' . a:parts[0] . ' is table, showing columns')
      else
        " table.col → still column completion
        let context.type = 'column'
        let context.table = a:parts[0]
        call s:debug('Hierarchical: ' . a:parts[0] . ' is table, partial column')
      endif
    else
      " Not found in cache - assume schema.table pattern
      let context.type = 'table'
      let context.schema = a:parts[0]
      call s:debug('Hierarchical: Assuming ' . a:parts[0] . ' is schema (not in cache)')
    endif

  elseif num_parts == 3
    " word1.word2.word3 - Check hierarchically:
    " 1. Is word1 a database AND word2 a schema? → word3 is partial table or show columns
    " 2. Is word1 a schema AND word2 a table? → word3 is column

    if s:is_database(a:db_key_name, a:parts[0])
      " word1 is a database
      " Trigger granular loading for tables if not already loaded
      call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'tables')

      if a:has_trailing_content
        " database.schema.tab → suggest tables
        let context.type = 'table'
        let context.database = a:parts[0]
        let context.schema = a:parts[1]
        call s:debug('Hierarchical: db.schema.partial_table')
      else
        " database.schema.table. → show columns
        let context.type = 'column'
        let context.database = a:parts[0]
        let context.schema = a:parts[1]
        let context.table = a:parts[2]
        call s:debug('Hierarchical: db.schema.table., showing columns')
      endif
    elseif s:is_schema(a:db_key_name, a:parts[0]) && s:is_table(a:db_key_name, a:parts[1], a:parts[0])
      " word1 is schema, word2 is table
      let context.type = 'column'
      let context.schema = a:parts[0]
      let context.table = a:parts[1]
      call s:debug('Hierarchical: schema.table.column')
    else
      " Assume database.schema.table pattern
      let context.type = 'table'
      let context.database = a:parts[0]
      let context.schema = a:parts[1]
      call s:debug('Hierarchical: Assuming db.schema.table pattern')
    endif
  endif

  return context
endfunction

" Get current procedure name being executed
" @param text - Text before cursor
" @return Procedure name or empty string
function! s:get_current_procedure_name(text) abort
  " Pattern: EXEC[UTE] procedure_name
  let match = matchlist(a:text, '\c\%(EXEC\|EXECUTE\)\s\+\([a-zA-Z0-9_.]\+\)')
  if !empty(match)
    return match[1]
  endif
  return ''
endfunction

" Parse query for external database references
" @param query_text - SQL query text
" @return List of external database names
function! db_ui#completion#parse_database_references(query_text) abort
  let databases = []

  " Pattern: DatabaseName.SchemaName.TableName or DatabaseName.TableName
  " Need to match database qualifier in:
  " - FROM/JOIN clauses: FROM MyDB.dbo.Users
  " - Column references: MyDB.dbo.Users.id
  " - SELECT list: SELECT MyDB.dbo.Users.name

  " Match multi-part identifiers (up to 4 parts: server.db.schema.table)
  let pattern = '\v<(\w+)\.(\w+)%(\.(\w+))?%(\.(\w+))?'

  let pos = 0
  while 1
    let match_pos = match(a:query_text, pattern, pos)
    if match_pos == -1
      break
    endif

    let match = matchlist(a:query_text, pattern, pos)
    if !empty(match)
      let first_part = match[1]
      let second_part = match[2]

      " If we have db.schema.table pattern, first part is the database
      " If we have db.table pattern, first part is the database
      " Skip if first part is a SQL keyword
      if !s:is_sql_keyword(first_part) && !empty(first_part)
        " Additional check: avoid common false positives
        " Skip if it looks like a function call (e.g., CAST.something)
        if !s:is_function_name(first_part)
          call add(databases, first_part)
        endif
      endif
    endif

    let pos = match_pos + 1
  endwhile

  " Return unique database names
  return uniq(sort(databases))
endfunction

" Check if string is a SQL keyword
" @param word - Word to check
" @return 1 if keyword, 0 otherwise
function! s:is_sql_keyword(word) abort
  let keywords = [
        \ 'SELECT', 'FROM', 'WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT', 'OUTER',
        \ 'CROSS', 'FULL', 'ON', 'AND', 'OR', 'NOT', 'IN', 'EXISTS', 'CASE',
        \ 'WHEN', 'THEN', 'ELSE', 'END', 'AS', 'ORDER', 'BY', 'GROUP', 'HAVING',
        \ 'LIMIT', 'OFFSET', 'UNION', 'INTERSECT', 'EXCEPT', 'INSERT', 'UPDATE',
        \ 'DELETE', 'CREATE', 'ALTER', 'DROP', 'TABLE', 'VIEW', 'INDEX',
        \ 'DATABASE', 'SCHEMA', 'USE', 'WITH', 'DISTINCT', 'ALL', 'TOP',
        \ 'BETWEEN', 'LIKE', 'IS', 'NULL', 'VALUES', 'SET', 'INTO', 'FOR',
        \ 'WHILE', 'IF', 'BEGIN', 'END', 'DECLARE', 'RETURN', 'EXEC', 'EXECUTE',
        \ 'PROCEDURE', 'FUNCTION', 'TRIGGER', 'PRIMARY', 'FOREIGN', 'KEY',
        \ 'CONSTRAINT', 'UNIQUE', 'CHECK', 'DEFAULT', 'IDENTITY', 'AUTO_INCREMENT'
        \ ]

  return index(keywords, toupper(a:word)) >= 0
endfunction

" Check if string is a common SQL function name
" @param word - Word to check
" @return 1 if function name, 0 otherwise
function! s:is_function_name(word) abort
  let functions = [
        \ 'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'CAST', 'CONVERT', 'COALESCE',
        \ 'ISNULL', 'NULLIF', 'CASE', 'LEN', 'LENGTH', 'UPPER', 'LOWER',
        \ 'SUBSTRING', 'TRIM', 'LTRIM', 'RTRIM', 'REPLACE', 'CONCAT',
        \ 'GETDATE', 'GETUTCDATE', 'DATEADD', 'DATEDIFF', 'YEAR', 'MONTH',
        \ 'DAY', 'ROUND', 'FLOOR', 'CEILING', 'ABS', 'POWER', 'SQRT',
        \ 'ROW_NUMBER', 'RANK', 'DENSE_RANK', 'NTILE', 'LAG', 'LEAD'
        \ ]

  return index(functions, toupper(a:word)) >= 0
endfunction

" ==============================================================================
" Formatting & Utilities
" ==============================================================================

" Format completion items
" @param items - Raw items (strings or dicts)
" @param type - Object type ('table', 'view', 'procedure', 'function', 'schema', 'database')
" @return List of formatted completion items
function! s:format_completions(items, type) abort
  let formatted = []

  for item in a:items
    if type(item) == v:t_string
      " Simple string item
      call add(formatted, {
            \ 'name': item,
            \ 'type': a:type,
            \ 'schema': '',
            \ 'full_name': item
            \ })
    elseif type(item) == v:t_dict
      " Dictionary item (already has metadata)
      let formatted_item = copy(item)
      if !has_key(formatted_item, 'type')
        let formatted_item.type = a:type
      endif
      if !has_key(formatted_item, 'full_name')
        let formatted_item.full_name = get(item, 'name', '')
      endif
      call add(formatted, formatted_item)
    endif
  endfor

  return formatted
endfunction

" Format column items with metadata
" @param columns - Raw column data
" @return List of formatted column completion items
function! s:format_columns(columns) abort
  let formatted = []

  for col in a:columns
    if type(col) == v:t_list && len(col) >= 2
      " [column_name, data_type]
      call add(formatted, {
            \ 'name': col[0],
            \ 'type': 'column',
            \ 'data_type': col[1],
            \ 'nullable': 1,
            \ 'is_pk': 0,
            \ 'is_fk': 0
            \ })
    elseif type(col) == v:t_dict
      " Already formatted
      let formatted_col = copy(col)
      if !has_key(formatted_col, 'type')
        let formatted_col.type = 'column'
      endif
      call add(formatted, formatted_col)
    endif
  endfor

  return formatted
endfunction

" ==============================================================================
" Status & Debugging
" ==============================================================================

" Show cache status for current buffer or all caches
" @return void
function! db_ui#completion#show_status() abort
  let db_key_name = get(b:, 'dbui_db_key_name', '')

  if empty(db_key_name)
    " Show all caches
    echo 'IntelliSense Cache Status:'
    echo '========================='
    echo 'Total caches: ' . len(s:completion_cache)
    echo ''

    for [key, cache] in items(s:completion_cache)
      echo 'Database: ' . key
      echo '  Tables: ' . len(cache.tables)
      echo '  Views: ' . len(cache.views)
      echo '  Procedures: ' . len(cache.procedures)
      echo '  Functions: ' . len(cache.functions)
      echo '  Schemas: ' . len(cache.schemas)
      echo '  Databases: ' . len(cache.databases)
      echo '  Cached columns for: ' . len(cache.columns_by_table) . ' tables'
      echo '  External DBs: ' . len(cache.external_databases)
      echo '  Age: ' . (localtime() - cache.last_updated) . 's / ' . cache.ttl . 's TTL'
      echo '  Loading: ' . (cache.loading ? 'Yes' : 'No')
      echo ''
    endfor
  else
    " Show cache for current buffer's database
    if has_key(s:completion_cache, db_key_name)
      let cache = s:completion_cache[db_key_name]
      echo 'IntelliSense Cache for: ' . db_key_name
      echo '======================================='
      echo 'Tables: ' . len(cache.tables)
      echo 'Views: ' . len(cache.views)
      echo 'Procedures: ' . len(cache.procedures)
      echo 'Functions: ' . len(cache.functions)
      echo 'Schemas: ' . len(cache.schemas)
      echo 'Databases: ' . len(cache.databases)
      echo 'Cached columns for: ' . len(cache.columns_by_table) . ' tables'
      echo 'External databases: ' . len(cache.external_databases)
      echo 'Cache age: ' . (localtime() - cache.last_updated) . 's / ' . cache.ttl . 's TTL'
      echo 'Loading: ' . (cache.loading ? 'Yes' : 'No')
    else
      echo 'No cache found for: ' . db_key_name
    endif
  endif
endfunction

" Toggle debug logging
" @return void
function! db_ui#completion#toggle_debug() abort
  let s:debug_enabled = !s:debug_enabled
  echo 'IntelliSense debug logging: ' . (s:debug_enabled ? 'enabled' : 'disabled')
endfunction

" Debug logging helper
" @param message - Debug message
" @return void
function! s:debug(message) abort
  if s:debug_enabled
    echom '[db_ui_completion] ' . a:message
  endif
endfunction

" ==============================================================================
" Public API for vim-dadbod-completion integration
" ==============================================================================

" Check if IntelliSense is available and enabled
" @return 1 if available, 0 otherwise
function! db_ui#completion#is_available() abort
  return get(g:, 'db_ui_enable_intellisense', 1) &&
        \ exists('*db_ui#get_conn_info')
endfunction

" Get all cached data for a database (for external completion plugins)
" @param db_key_name - Database identifier
" @return Dictionary with all cached data
function! db_ui#completion#get_all_cached_data(db_key_name) abort
  if !has_key(s:completion_cache, a:db_key_name)
    return {}
  endif

  return copy(s:completion_cache[a:db_key_name])
endfunction

" ==============================================================================
" Automatic External Database Caching
" ==============================================================================

" Hook called before query execution to detect and cache external databases
" @return void
function! db_ui#completion#on_query_pre() abort
  if !get(g:, 'db_ui_enable_intellisense', 1)
    return
  endif

  if !get(g:, 'db_ui_intellisense_fetch_external_db', 1)
    return
  endif

  " Get current buffer's database key
  let db_key_name = get(b:, 'dbui_db_key_name', '')
  if empty(db_key_name)
    return
  endif

  " Get the query being executed
  let query_lines = getline(1, '$')
  let query_text = join(query_lines, ' ')

  " Parse for external database references
  let external_dbs = db_ui#completion#parse_database_references(query_text)

  if empty(external_dbs)
    call s:debug('No external databases found in query')
    return
  endif

  call s:debug('Found external databases in query: ' . string(external_dbs))

  " Fetch metadata for each external database asynchronously
  for ext_db in external_dbs
    call s:debug('Triggering fetch for external DB: ' . ext_db)
    call db_ui#completion#fetch_external_database(db_key_name, ext_db)
  endfor
endfunction

" Initialize autocmds for automatic external database caching
" @return void
function! db_ui#completion#setup_autocmds() abort
  if !get(g:, 'db_ui_enable_intellisense', 1)
    return
  endif

  augroup dbui_intellisense
    autocmd!
    " Hook into query execution to detect external database references
    autocmd User *DBExecutePre call db_ui#completion#on_query_pre()
  augroup END

  call s:debug('IntelliSense autocmds initialized')
endfunction

" Initialize the IntelliSense system (called from plugin initialization)
call db_ui#completion#setup_autocmds()
