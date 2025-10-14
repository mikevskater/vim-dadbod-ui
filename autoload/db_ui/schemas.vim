function! s:strip_quotes(results) abort
  return split(substitute(join(a:results),'"','','g'))
endfunction

function! s:results_parser(results, delimiter, min_len) abort
  if a:min_len ==? 1
    return filter(a:results, '!empty(trim(v:val))')
  endif
  let mapped = map(a:results, {_,row -> filter(split(row, a:delimiter), '!empty(trim(v:val))')})
  if a:min_len > 1
    return filter(mapped, 'len(v:val) ==? '.a:min_len)
  endif

  let counts = map(copy(mapped), 'len(v:val)')
  let min_len = max(counts)

  return filter(mapped,'len(v:val) ==? '.min_len)
endfunction

let s:postgres_foreign_key_query = "
      \ SELECT ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name, ccu.table_schema as foreign_table_schema
      \ FROM
      \     information_schema.table_constraints AS tc
      \     JOIN information_schema.key_column_usage AS kcu
      \       ON tc.constraint_name = kcu.constraint_name
      \     JOIN information_schema.constraint_column_usage AS ccu
      \       ON ccu.constraint_name = tc.constraint_name
      \ WHERE constraint_type = 'FOREIGN KEY' and kcu.column_name = '{col_name}' LIMIT 1"

let s:postgres_list_schema_query = "
    \ SELECT nspname as schema_name
    \ FROM pg_catalog.pg_namespace
    \ WHERE nspname !~ '^pg_temp_'
    \   and pg_catalog.has_schema_privilege(current_user, nspname, 'USAGE')
    \ order by nspname"

if empty(g:db_ui_use_postgres_views)
  let postgres_tables_and_views = "
        \ SELECT table_schema, table_name FROM information_schema.tables ;"
else
  let postgres_tables_and_views = "
        \ SELECT table_schema, table_name FROM information_schema.tables UNION ALL
        \ select schemaname, matviewname from pg_matviews;"
endif
let s:postgres_tables_and_views = postgres_tables_and_views

let s:postgresql = {
      \ 'args': ['-A', '-c'],
      \ 'foreign_key_query': s:postgres_foreign_key_query,
      \ 'schemes_query': s:postgres_list_schema_query,
      \ 'schemes_tables_query': s:postgres_tables_and_views,
      \ 'select_foreign_key_query': 'select * from "%s"."%s" where "%s" = %s',
      \ 'cell_line_number': 2,
      \ 'cell_line_pattern': '^-\++-\+',
      \ 'parse_results': {results,min_len -> s:results_parser(filter(results, '!empty(v:val)')[1:-2], '|', min_len)},
      \ 'default_scheme': 'public',
      \ 'layout_flag': '\\x',
      \ 'quote': 1,
      \ }

let s:sqlserver_foreign_keys_query = "
      \ SELECT TOP 1 c2.table_name as foreign_table_name, kcu2.column_name as foreign_column_name, kcu2.table_schema as foreign_table_schema
      \ from   information_schema.table_constraints c
      \        inner join information_schema.key_column_usage kcu
      \          on c.constraint_schema = kcu.constraint_schema and c.constraint_name = kcu.constraint_name
      \        inner join information_schema.referential_constraints rc
      \          on c.constraint_schema = rc.constraint_schema and c.constraint_name = rc.constraint_name
      \        inner join information_schema.table_constraints c2
      \          on rc.unique_constraint_schema = c2.constraint_schema and rc.unique_constraint_name = c2.constraint_name
      \        inner join information_schema.key_column_usage kcu2
      \          on c2.constraint_schema = kcu2.constraint_schema and c2.constraint_name = kcu2.constraint_name and kcu.ordinal_position = kcu2.ordinal_position
      \ where  c.constraint_type = 'FOREIGN KEY'
      \ and kcu.column_name = '{col_name}'
      \ "

let s:sqlserver = {
      \   'args': ['-h-1', '-W', '-s', '|', '-Q'],
      \   'foreign_key_query': trim(s:sqlserver_foreign_keys_query),
      \   'schemes_query': 'SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA',
      \   'schemes_tables_query': 'SELECT table_schema, table_name FROM INFORMATION_SCHEMA.TABLES',
      \   'select_foreign_key_query': 'select * from %s.%s where %s = %s',
      \   'cell_line_number': 2,
      \   'cell_line_pattern': '^-\+.-\+',
      \   'parse_results': {results, min_len -> s:results_parser(results[0:-3], '|', min_len)},
      \   'quote': 0,
      \   'default_scheme': 'dbo',
      \ }

let s:mysql_foreign_key_query =  "
      \ SELECT referenced_table_name, referenced_column_name, referenced_table_schema
      \ from information_schema.key_column_usage
      \ where referenced_table_name is not null and column_name = '{col_name}' LIMIT 1"
let s:mysql = {
      \ 'foreign_key_query': s:mysql_foreign_key_query,
      \ 'schemes_query': 'SELECT schema_name FROM information_schema.schemata',
      \ 'schemes_tables_query': 'SELECT table_schema, table_name FROM information_schema.tables',
      \ 'select_foreign_key_query': 'select * from %s.%s where %s = %s',
      \ 'cell_line_number': 3,
      \ 'requires_stdin': v:true,
      \ 'cell_line_pattern': '^+-\++-\+',
      \ 'parse_results': {results, min_len -> s:results_parser(results[1:], '\t', min_len)},
      \ 'default_scheme': '',
      \ 'layout_flag': '\\G',
      \ 'quote': 0,
      \ 'filetype': 'mysql',
      \ }

let s:oracle_args = join(
      \    [
           \  'SET linesize 4000',
           \  'SET pagesize 4000',
           \  'COLUMN owner FORMAT a20',
           \  'COLUMN table_name FORMAT a25',
           \  'COLUMN column_name FORMAT a25',
           \  '%s',
      \    ],
      \    ";\n"
      \ ).';'

function! s:get_oracle_queries()
  let common_condition = ""

  if !g:db_ui_is_oracle_legacy
    let common_condition = "AND U.common = 'NO'"
  endif

  let foreign_key_query = "
      \SELECT /*csv*/ DISTINCT RFRD.table_name, RFRD.column_name, RFRD.owner
      \ FROM all_cons_columns RFRD
      \ JOIN all_constraints CON ON RFRD.constraint_name = CON.r_constraint_name
      \ JOIN all_cons_columns RFRING ON CON.constraint_name = RFRING.constraint_name
      \ JOIN all_users U ON CON.owner = U.username
      \ WHERE CON.constraint_type = 'R'
      \ " . common_condition . "
      \ AND RFRING.column_name = '{col_name}'"

  let schemes_query = "
      \SELECT /*csv*/ username
      \ FROM all_users U
      \ WHERE 1 = 1 
      \ " . common_condition . "
      \ ORDER BY username"

  let schemes_tables_query = "
      \SELECT /*csv*/ T.owner, T.table_name
      \ FROM (
      \ SELECT owner, table_name
      \ FROM all_tables
      \ UNION SELECT owner, view_name AS \"table_name\"
      \ FROM all_views
      \ ) T
      \ JOIN all_users U ON T.owner = U.username
      \ WHERE 1 = 1
      \ " . common_condition . "
      \ ORDER BY T.table_name"

  return {
      \ 'foreign_key_query': printf(s:oracle_args, foreign_key_query),
      \ 'schemes_query': printf(s:oracle_args, schemes_query),
      \ 'schemes_tables_query': printf(s:oracle_args, schemes_tables_query),
      \ }
endfunction

let oracle_queries = s:get_oracle_queries()

let s:oracle = {
      \   'callable': 'filter',
      \   'cell_line_number': 1,
      \   'cell_line_pattern': '^-\+\( \+-\+\)*',
      \   'default_scheme': '',
      \   'foreign_key_query': oracle_queries.foreign_key_query,
      \   'has_virtual_results': v:true,
      \   'parse_results': {results, min_len -> s:results_parser(results[3:], '\s\s\+', min_len)},
      \   'parse_virtual_results': {results, min_len -> s:results_parser(results[3:], '\s\s\+', min_len)},
      \   'requires_stdin': v:true,
      \   'quote': v:true,
      \   'schemes_query': oracle_queries.schemes_query,
      \   'schemes_tables_query': oracle_queries.schemes_tables_query,
      \   'select_foreign_key_query': printf(s:oracle_args, 'SELECT /*csv*/ * FROM "%s"."%s" WHERE "%s" = %s'),
      \   'filetype': 'plsql',
      \ }

if index(['sql', 'sqlcl'], get(g:, 'dbext_default_ORA_bin', '')) >= 0
  let s:oracle.parse_results = {results, min_len -> s:results_parser(s:strip_quotes(results[3:]), ',', min_len)}
  let s:oracle.parse_virtual_results = {results, min_len -> s:results_parser(s:strip_quotes(results[3:]), ',', min_len)}
endif

if !exists('g:db_adapter_bigquery_region')
  let g:db_adapter_bigquery_region = 'region-us'
endif

let s:bigquery_schemas_query = printf("
      \ SELECT schema_name FROM `%s`.INFORMATION_SCHEMA.SCHEMATA
      \ ", g:db_adapter_bigquery_region)

let s:bigquery_schema_tables_query = printf("
      \ SELECT table_schema, table_name
      \ FROM `%s`.INFORMATION_SCHEMA.TABLES
      \ ", g:db_adapter_bigquery_region)

let s:db_adapter_bigquery_max_results = 100000
let s:bigquery = {
      \ 'callable': 'filter',
      \ 'args': ['--format=csv', '--max_rows=' .. s:db_adapter_bigquery_max_results],
      \ 'schemes_query': s:bigquery_schemas_query,
      \ 'schemes_tables_query': s:bigquery_schema_tables_query,
      \ 'parse_results': {results, min_len -> s:results_parser(results[1:], ',', min_len)},
      \ 'layout_flag': '\\x',
      \ 'requires_stdin': v:true,
      \ }


let s:clickhouse_schemes_query = "
      \ SELECT name as schema_name
      \ FROM system.databases
      \ ORDER BY name"

let s:clickhouse_schemes_tables_query = "
      \ SELECT database AS table_schema, name AS table_name
      \ FROM system.tables
      \ ORDER BY table_name"

let s:clickhouse = {
      \ 'args': ['-q'],
      \ 'schemes_query': trim(s:clickhouse_schemes_query),
      \ 'schemes_tables_query': trim(s:clickhouse_schemes_tables_query),
      \ 'cell_line_number': 1,
      \ 'cell_line_pattern': '^.*$',
      \ 'parse_results': {results, min_len -> s:results_parser(results, '\t', min_len)},
      \ 'default_scheme': '',
      \ 'quote': 1,
      \ }

" Add ClickHouse to the schemas dictionary
let s:schemas = {
      \ 'postgres': s:postgresql,
      \ 'postgresql': s:postgresql,
      \ 'sqlserver': s:sqlserver,
      \ 'mysql': s:mysql,
      \ 'mariadb': s:mysql,
      \ 'oracle': s:oracle,
      \ 'bigquery': s:bigquery,
      \ 'clickhouse': s:clickhouse,
      \ }


if !exists('g:db_adapter_postgres')
  let g:db_adapter_postgres = 'db#adapter#postgresql#'
endif

if !exists('g:db_adapter_sqlite3')
  let g:db_adapter_sqlite3 = 'db#adapter#sqlite#'
endif

function! db_ui#schemas#get(scheme) abort
  return get(s:schemas, a:scheme, {})
endfunction

function! s:format_query(db, scheme, query) abort
  let conn = type(a:db) == v:t_string ? a:db : a:db.conn
  let callable = get(a:scheme, 'callable', 'interactive')
  let cmd = db#adapter#dispatch(conn, callable) + get(a:scheme, 'args', [])
  if get(a:scheme, 'requires_stdin', v:false)
    return [cmd, a:query]
  endif
  return [cmd + [a:query], '']
endfunction

function! db_ui#schemas#query(db, scheme, query) abort
  let result = call('db#systemlist', s:format_query(a:db, a:scheme, a:query))
  return map(result, {_, val -> substitute(val, "\r$", "", "")})
endfunction

function db_ui#schemas#supports_schemes(scheme, parsed_url)
  let schema_support = !empty(get(a:scheme, 'schemes_query', 0))
  if empty(schema_support)
    return 0
  endif
  let scheme_name = tolower(get(a:parsed_url, 'scheme', ''))
  " Mysql and MariaDB should not show schemas if the path (database name) is
  " defined
  if (scheme_name ==? 'mysql' || scheme_name ==? 'mariadb') && a:parsed_url.path !=? '/'
    return 0
  endif

  return 1
endfunction

" autoload/db_ui/schemas.vim
" Database Schema Registry and Coordinator
" This file loads and manages individual database schema modules

" =============================================================================
" Schema Module Registry
" =============================================================================

let s:loaded_schemas = {}
let s:schema_modules = {}

" =============================================================================
" Module Loading
" =============================================================================

" Load a schema module from autoload/db_ui/schemas/{scheme}.vim
function! s:load_schema_module(scheme) abort
  " Check if already loaded
  if has_key(s:loaded_schemas, a:scheme)
    return s:loaded_schemas[a:scheme]
  endif
  
  " Try to load the module file
  let module_file = 'autoload/db_ui/schemas/' . a:scheme . '.vim'
  
  " Check if file exists
  if !empty(findfile(module_file, escape(&rtp, ' '))) || 
        \ (exists('*nvim_get_runtime_file') && 
        \  !empty(nvim_get_runtime_file(module_file, v:false)))
    
    " Source the module file
    execute 'runtime!' module_file
    
    " Get the schema definition from the module
    " Each module should define db_ui#schemas#{scheme}#get()
    let GetSchema = function('db_ui#schemas#' . a:scheme . '#get')
    let s:loaded_schemas[a:scheme] = GetSchema()
    
    call db_ui#utils#print_debug('Loaded schema module: ' . a:scheme)
  else
    " Module not found - return empty dict
    call db_ui#utils#print_debug('Schema module not found: ' . a:scheme)
    return {}
  endif
  
  return get(s:loaded_schemas, a:scheme, {})
endfunction

" =============================================================================
" Public API - Get Schema
" =============================================================================

" Get schema definition for a database type
" This is the main entry point for getting schema information
function! db_ui#schemas#get(scheme) abort
  " Normalize scheme name
  let scheme = tolower(a:scheme)
  
  " Handle aliases
  let aliases = {
        \ 'postgres': 'postgresql',
        \ 'sqlite3': 'sqlite',
        \ 'mariadb': 'mysql',
        \ }
  let scheme = get(aliases, scheme, scheme)
  
  " Load module if not already loaded
  return s:load_schema_module(scheme)
endfunction

" =============================================================================
" Query Execution Helpers
" =============================================================================

" Execute a query in a specific database context
" Adds USE statement if supported by the database type
function! db_ui#schemas#query_in_database(db, scheme, database_name, query) abort
  let use_template = get(a:scheme, 'use_statement_template', '')
  
  " If USE statements are disabled globally, skip them
  if !g:db_ui_add_use_statement || empty(use_template)
    return db_ui#schemas#query(a:db, a:scheme, a:query)
  endif
  
  " Generate USE statement
  let use_stmt = substitute(use_template, '{database}', a:database_name, 'g')
  let full_query = use_stmt . a:query
  
  call db_ui#schemas#debug_query('Query in database: ' . a:database_name, full_query)
  
  return db_ui#schemas#query(a:db, a:scheme, full_query)
endfunction

" =============================================================================
" Feature Detection
" =============================================================================

" Check if a database scheme supports a specific feature
function! db_ui#schemas#supports_feature(scheme, feature) abort
  return get(a:scheme, 'supports_' . a:feature, 0)
endfunction

" Check if scheme supports database-level browsing
function! db_ui#schemas#supports_databases(scheme_name) abort
  let scheme = db_ui#schemas#get(a:scheme_name)
  return get(scheme, 'supports_databases', 0)
endfunction

" =============================================================================
" Database Filtering
" =============================================================================

" Get list of ignored databases for a scheme
function! db_ui#schemas#get_ignored_databases(scheme_name) abort
  " Get user-defined ignored databases
  let user_ignored = get(g:db_ui_ignored_databases, a:scheme_name, [])
  
  " Get default ignored databases
  let default_ignored = get(g:db_ui_default_ignored_databases, a:scheme_name, [])
  
  " Merge them (user list takes precedence)
  return extend(copy(default_ignored), user_ignored)
endfunction

" Check if a database should be ignored
function! db_ui#schemas#is_database_ignored(scheme_name, database_name) abort
  let ignored_list = db_ui#schemas#get_ignored_databases(a:scheme_name)
  return index(ignored_list, a:database_name) >= 0
endfunction

" =============================================================================
" Object Filtering
" =============================================================================

" Check if an object should be shown based on system object settings
function! db_ui#schemas#should_show_object(is_system) abort
  " If is_system flag is 0 (user object), always show
  if !a:is_system
    return 1
  endif
  
  " If is_system flag is 1, only show if configured to show system objects
  return g:db_ui_show_system_objects
endfunction

" Get display name for an object (adds system prefix if needed)
function! db_ui#schemas#get_object_display_name(name, is_system) abort
  if a:is_system && g:db_ui_show_system_objects
    return g:db_ui_system_object_prefix . a:name
  endif
  return a:name
endfunction

" =============================================================================
" Query Template Substitution
" =============================================================================

" Substitute placeholders in a query template
" Supports: {database}, {schema}, {object}, {table}, {column}
function! db_ui#schemas#substitute_query_params(query, params) abort
  let result = a:query
  
  for [key, value] in items(a:params)
    let placeholder = '{' . key . '}'
    let result = substitute(result, placeholder, value, 'g')
  endfor
  
  return result
endfunction

" =============================================================================
" Object Definition Retrieval
" =============================================================================

" Get object definition with proper query for the object type
function! db_ui#schemas#get_object_definition(db, scheme, database_name, schema_name, object_name, object_type) abort
  " Check if scheme has a custom definition function
  if has_key(a:scheme, 'get_object_definition')
    return a:scheme.get_object_definition(
          \ a:db, a:database_name, a:schema_name, a:object_name, a:object_type)
  endif
  
  " Default implementation
  let query = get(a:scheme, 'object_definition_query', '')
  
  if empty(query)
    return ['-- Object definition not available for this database type']
  endif
  
  " Substitute parameters
  let query = db_ui#schemas#substitute_query_params(query, {
        \ 'database': a:database_name,
        \ 'schema': a:schema_name,
        \ 'object': a:object_name,
        \ })
  
  " Execute query in database context
  let results = db_ui#schemas#query_in_database(
        \ a:db, a:scheme, a:database_name, query)
  
  if empty(results)
    return ['-- Definition not found']
  endif
  
  return results
endfunction

" =============================================================================
" Results Processing
" =============================================================================

" Parse query results into structured format
" Returns: [[col1, col2, ...], [col1, col2, ...], ...]
function! db_ui#schemas#parse_query_results(scheme, results, expected_columns) abort
  " Use the scheme's parse_results function if available
  if has_key(a:scheme, 'parse_results')
    return a:scheme.parse_results(a:results, a:expected_columns)
  endif
  
  " Default parsing: assume tab-separated values, skip header row
  let parsed = []
  for i in range(1, len(a:results) - 1)
    let row = split(a:results[i], "\t")
    if len(row) >= a:expected_columns
      call add(parsed, row)
    endif
  endfor
  
  return parsed
endfunction

" =============================================================================
" Debugging Helpers
" =============================================================================

" Log a query execution for debugging
function! db_ui#schemas#debug_query(message, query) abort
  if !g:db_ui_debug
    return
  endif
  
  call db_ui#utils#print_debug({
        \ 'schema_query': a:message,
        \ 'query': a:query
        \ })
endfunction

" =============================================================================
" Utility Functions (Kept for backward compatibility)
" =============================================================================

" These functions forward to the existing db_ui#schemas#query() function
" which is defined in the main vim-dadbod-ui codebase

" Note: The actual query execution is handled by the existing
" db_ui#schemas#query() function which interfaces with vim-dadbod.
" We're just adding database-level and object-level query support on top.