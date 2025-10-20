" ==============================================================================
" Query Result Caching System
" ==============================================================================

" Cache storage: { 'cache_key': { 'data': [...], 'timestamp': 12345 } }
let s:query_cache = {}

" Generate a unique cache key from query parameters
function! s:generate_cache_key(db, query) abort
  let db_name = type(a:db) == v:t_string ? a:db : get(a:db, 'name', 'unknown')
  let query_hash = string(a:query)
  return db_name . '|' . query_hash
endfunction

" Check if cached result is still valid (within TTL)
function! s:is_cache_valid(cache_key) abort
  if !has_key(s:query_cache, a:cache_key)
    return 0
  endif

  let cache_entry = s:query_cache[a:cache_key]
  let current_time = localtime()
  let age = current_time - cache_entry.timestamp
  let ttl = get(g:, 'db_ui_cache_ttl', 300)  " Default: 5 minutes

  return age < ttl
endfunction

" Get cached result if valid
function! s:get_cached_result(cache_key) abort
  if s:is_cache_valid(a:cache_key)
    return s:query_cache[a:cache_key].data
  endif
  return []
endfunction

" Store result in cache
function! s:cache_result(cache_key, result) abort
  let s:query_cache[a:cache_key] = {
        \ 'data': a:result,
        \ 'timestamp': localtime()
        \ }
endfunction

" Clear all cache entries
function! db_ui#schemas#clear_cache() abort
  let s:query_cache = {}
  echom 'Database query cache cleared'
endfunction

" Clear cache for specific database
function! db_ui#schemas#clear_cache_for(db_name) abort
  let keys_to_remove = []
  for key in keys(s:query_cache)
    if key =~# '^' . a:db_name . '|'
      call add(keys_to_remove, key)
    endif
  endfor

  for key in keys_to_remove
    unlet s:query_cache[key]
  endfor

  echom 'Cache cleared for database: ' . a:db_name
endfunction

" ==============================================================================
" Helper Functions
" ==============================================================================

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

let s:postgres_databases_query = "
      \ SELECT datname as database_name
      \ FROM pg_database
      \ WHERE datistemplate = false
      \ ORDER BY datname"

let s:postgres_views_query = "
      \ SELECT schemaname as table_schema, viewname as view_name
      \ FROM pg_views
      \ WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      \ ORDER BY schemaname, viewname"

let s:postgres_procedures_query = "
      \ SELECT n.nspname as schema_name, p.proname as procedure_name
      \ FROM pg_proc p
      \ JOIN pg_namespace n ON p.pronamespace = n.oid
      \ WHERE p.prokind = 'p' AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      \ ORDER BY n.nspname, p.proname"

let s:postgres_functions_query = "
      \ SELECT n.nspname as schema_name, p.proname as function_name
      \ FROM pg_proc p
      \ JOIN pg_namespace n ON p.pronamespace = n.oid
      \ WHERE p.prokind = 'f' AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      \ ORDER BY n.nspname, p.proname"

let s:postgres_columns_query = "
      \ SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
      \ FROM information_schema.columns
      \ WHERE table_schema = '{schema}' AND table_name = '{table}'
      \ ORDER BY ordinal_position"

let s:postgres_indexes_query = "
      \ SELECT indexname as index_name, indexdef
      \ FROM pg_indexes
      \ WHERE schemaname = '{schema}' AND tablename = '{table}'
      \ ORDER BY indexname"

let s:postgres_primary_keys_query = "
      \ SELECT kcu.column_name, tc.constraint_name
      \ FROM information_schema.table_constraints tc
      \ JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      \ WHERE tc.table_schema = '{schema}' AND tc.table_name = '{table}' AND tc.constraint_type = 'PRIMARY KEY'
      \ ORDER BY kcu.ordinal_position"

let s:postgres_foreign_keys_query_detail = "
      \ SELECT tc.constraint_name, kcu.column_name, ccu.table_schema AS referenced_schema,
      \ ccu.table_name AS referenced_table, ccu.column_name AS referenced_column
      \ FROM information_schema.table_constraints tc
      \ JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      \ JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
      \ WHERE tc.table_schema = '{schema}' AND tc.table_name = '{table}' AND tc.constraint_type = 'FOREIGN KEY'
      \ ORDER BY tc.constraint_name"

let s:postgres_constraints_query = "
      \ SELECT tc.constraint_name, tc.constraint_type, cc.check_clause
      \ FROM information_schema.table_constraints tc
      \ LEFT JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
      \ WHERE tc.table_schema = '{schema}' AND tc.table_name = '{table}' AND tc.constraint_type IN ('CHECK', 'UNIQUE')
      \ ORDER BY tc.constraint_name"

let s:postgres_parameters_query = "
      \ SELECT p.parameter_name, p.data_type, p.parameter_mode, p.character_maximum_length
      \ FROM information_schema.parameters p
      \ WHERE p.specific_schema = '{schema}' AND p.specific_name = '{object_name}'
      \ ORDER BY p.ordinal_position"

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
      \ 'databases_query': trim(s:postgres_databases_query),
      \ 'views_query': trim(s:postgres_views_query),
      \ 'procedures_query': trim(s:postgres_procedures_query),
      \ 'functions_query': trim(s:postgres_functions_query),
      \ 'columns_query': trim(s:postgres_columns_query),
      \ 'indexes_query': trim(s:postgres_indexes_query),
      \ 'primary_keys_query': trim(s:postgres_primary_keys_query),
      \ 'foreign_keys_query_detail': trim(s:postgres_foreign_keys_query_detail),
      \ 'constraints_query': trim(s:postgres_constraints_query),
      \ 'parameters_query': trim(s:postgres_parameters_query),
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

let s:sqlserver_databases_query = "
      \ SELECT name as database_name
      \ FROM sys.databases
      \ WHERE database_id > 4
      \ ORDER BY name"

let s:sqlserver_views_query = "
      \ SELECT SCHEMA_NAME(schema_id) as table_schema, name as view_name
      \ FROM sys.views
      \ ORDER BY table_schema, view_name"

let s:sqlserver_procedures_query = "
      \ SELECT SCHEMA_NAME(schema_id) as schema_name, name as procedure_name
      \ FROM sys.procedures
      \ ORDER BY schema_name, procedure_name"

let s:sqlserver_functions_query = "
      \ SELECT SCHEMA_NAME(schema_id) as schema_name, name as function_name
      \ FROM sys.objects
      \ WHERE type IN ('FN', 'IF', 'TF', 'FS', 'FT')
      \ ORDER BY schema_name, function_name"

let s:sqlserver_columns_query = "
      \ SELECT c.COLUMN_NAME, c.DATA_TYPE, c.CHARACTER_MAXIMUM_LENGTH, c.IS_NULLABLE, c.COLUMN_DEFAULT
      \ FROM INFORMATION_SCHEMA.COLUMNS c
      \ WHERE c.TABLE_SCHEMA = '{schema}' AND c.TABLE_NAME = '{table}'
      \ ORDER BY c.ORDINAL_POSITION"

let s:sqlserver_indexes_query = "
      \ SELECT i.name AS index_name, i.type_desc, i.is_unique, i.is_primary_key
      \ FROM sys.indexes i
      \ WHERE i.object_id = OBJECT_ID('[{schema}].[{table}]') AND i.name IS NOT NULL
      \ ORDER BY i.name"

let s:sqlserver_primary_keys_query = "
      \ SELECT kcu.COLUMN_NAME, tc.CONSTRAINT_NAME
      \ FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
      \ JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
      \ WHERE tc.TABLE_SCHEMA = '{schema}' AND tc.TABLE_NAME = '{table}' AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
      \ ORDER BY kcu.ORDINAL_POSITION"

let s:sqlserver_foreign_keys_query_detail = "
      \ SELECT fk.name AS constraint_name, COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS column_name,
      \ OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema, OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
      \ COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS referenced_column
      \ FROM sys.foreign_keys fk
      \ JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
      \ WHERE fk.parent_object_id = OBJECT_ID('[{schema}].[{table}]')
      \ ORDER BY fk.name"

let s:sqlserver_constraints_query = "
      \ SELECT tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE, cc.CHECK_CLAUSE
      \ FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
      \ LEFT JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
      \ WHERE tc.TABLE_SCHEMA = '{schema}' AND tc.TABLE_NAME = '{table}' AND tc.CONSTRAINT_TYPE IN ('CHECK', 'UNIQUE')
      \ ORDER BY tc.CONSTRAINT_NAME"

let s:sqlserver_parameters_query = "
      \ SELECT p.PARAMETER_NAME, p.DATA_TYPE, p.PARAMETER_MODE, p.CHARACTER_MAXIMUM_LENGTH
      \ FROM INFORMATION_SCHEMA.PARAMETERS p
      \ WHERE p.SPECIFIC_SCHEMA = '{schema}' AND p.SPECIFIC_NAME = '{object_name}'
      \ ORDER BY p.ORDINAL_POSITION"

let s:sqlserver_dependencies_query = "
      \ SELECT OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema, OBJECT_NAME(referencing_id) AS ReferencingObject,
      \ o.type_desc AS ReferencingType, OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema,
      \ OBJECT_NAME(referenced_id) AS ReferencedObject, o2.type_desc AS ReferencedType
      \ FROM sys.sql_expression_dependencies sed
      \ JOIN sys.objects o ON sed.referencing_id = o.object_id
      \ LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id
      \ WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{object}]') OR sed.referenced_id = OBJECT_ID('[{schema}].[{object}]')
      \ ORDER BY ReferencingSchema, ReferencingObject"

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
      \   'databases_query': trim(s:sqlserver_databases_query),
      \   'views_query': trim(s:sqlserver_views_query),
      \   'procedures_query': trim(s:sqlserver_procedures_query),
      \   'functions_query': trim(s:sqlserver_functions_query),
      \   'columns_query': trim(s:sqlserver_columns_query),
      \   'indexes_query': trim(s:sqlserver_indexes_query),
      \   'primary_keys_query': trim(s:sqlserver_primary_keys_query),
      \   'foreign_keys_query_detail': trim(s:sqlserver_foreign_keys_query_detail),
      \   'constraints_query': trim(s:sqlserver_constraints_query),
      \   'parameters_query': trim(s:sqlserver_parameters_query),
      \   'dependencies_query': trim(s:sqlserver_dependencies_query),
      \ }

let s:mysql_foreign_key_query =  "
      \ SELECT referenced_table_name, referenced_column_name, referenced_table_schema
      \ from information_schema.key_column_usage
      \ where referenced_table_name is not null and column_name = '{col_name}' LIMIT 1"

let s:mysql_databases_query = "
      \ SELECT schema_name as database_name
      \ FROM information_schema.schemata
      \ ORDER BY schema_name"

let s:mysql_views_query = "
      \ SELECT table_schema, table_name as view_name
      \ FROM information_schema.views
      \ ORDER BY table_schema, table_name"

let s:mysql_procedures_query = "
      \ SELECT routine_schema as schema_name, routine_name as procedure_name
      \ FROM information_schema.routines
      \ WHERE routine_type = 'PROCEDURE'
      \ ORDER BY routine_schema, routine_name"

let s:mysql_functions_query = "
      \ SELECT routine_schema as schema_name, routine_name as function_name
      \ FROM information_schema.routines
      \ WHERE routine_type = 'FUNCTION'
      \ ORDER BY routine_schema, routine_name"

let s:mysql_columns_query = "
      \ SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
      \ FROM information_schema.columns
      \ WHERE table_schema = '{schema}' AND table_name = '{table}'
      \ ORDER BY ordinal_position"

let s:mysql_indexes_query = "
      \ SELECT index_name, index_type, non_unique
      \ FROM information_schema.statistics
      \ WHERE table_schema = '{schema}' AND table_name = '{table}'
      \ GROUP BY index_name, index_type, non_unique
      \ ORDER BY index_name"

let s:mysql_primary_keys_query = "
      \ SELECT column_name, constraint_name
      \ FROM information_schema.key_column_usage
      \ WHERE table_schema = '{schema}' AND table_name = '{table}' AND constraint_name = 'PRIMARY'
      \ ORDER BY ordinal_position"

let s:mysql_foreign_keys_query_detail = "
      \ SELECT constraint_name, column_name, referenced_table_schema, referenced_table_name, referenced_column_name
      \ FROM information_schema.key_column_usage
      \ WHERE table_schema = '{schema}' AND table_name = '{table}' AND referenced_table_name IS NOT NULL
      \ ORDER BY constraint_name"

let s:mysql_constraints_query = "
      \ SELECT constraint_name, constraint_type
      \ FROM information_schema.table_constraints
      \ WHERE table_schema = '{schema}' AND table_name = '{table}' AND constraint_type IN ('CHECK', 'UNIQUE')
      \ ORDER BY constraint_name"

let s:mysql_parameters_query = "
      \ SELECT parameter_name, data_type, parameter_mode, character_maximum_length
      \ FROM information_schema.parameters
      \ WHERE specific_schema = '{schema}' AND specific_name = '{object_name}'
      \ ORDER BY ordinal_position"

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
      \ 'databases_query': trim(s:mysql_databases_query),
      \ 'views_query': trim(s:mysql_views_query),
      \ 'procedures_query': trim(s:mysql_procedures_query),
      \ 'functions_query': trim(s:mysql_functions_query),
      \ 'columns_query': trim(s:mysql_columns_query),
      \ 'indexes_query': trim(s:mysql_indexes_query),
      \ 'primary_keys_query': trim(s:mysql_primary_keys_query),
      \ 'foreign_keys_query_detail': trim(s:mysql_foreign_keys_query_detail),
      \ 'constraints_query': trim(s:mysql_constraints_query),
      \ 'parameters_query': trim(s:mysql_parameters_query),
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
  " Check if caching is enabled
  let cache_enabled = get(g:, 'db_ui_cache_enabled', 1)

  if cache_enabled
    " Generate cache key
    let cache_key = s:generate_cache_key(a:db, a:query)

    " Try to get cached result
    let cached_result = s:get_cached_result(cache_key)
    if !empty(cached_result) || s:is_cache_valid(cache_key)
      return cached_result
    endif
  endif

  " Show loading indicator if enabled
  if g:db_ui_show_loading_indicator
    echom 'Loading database objects...'
  endif

  " Execute query if not cached or cache disabled
  let result = call('db#systemlist', s:format_query(a:db, a:scheme, a:query))
  let result = map(result, {_, val -> substitute(val, "\r$", "", "")})

  " Store in cache if enabled
  if cache_enabled
    call s:cache_result(cache_key, result)
  endif

  " Clear loading indicator
  if g:db_ui_show_loading_indicator
    echo ''
  endif

  return result
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

" SSMS-style helper functions
function! db_ui#schemas#supports_databases(scheme) abort
  return !empty(get(a:scheme, 'databases_query', ''))
endfunction

function! db_ui#schemas#query_databases(db, scheme) abort
  let query = get(a:scheme, 'databases_query', '')
  if empty(query)
    return []
  endif
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_views(db, scheme) abort
  let query = get(a:scheme, 'views_query', '')
  if empty(query)
    return []
  endif
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_procedures(db, scheme) abort
  let query = get(a:scheme, 'procedures_query', '')
  if empty(query)
    return []
  endif
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_functions(db, scheme) abort
  let query = get(a:scheme, 'functions_query', '')
  if empty(query)
    return []
  endif
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_columns(db, scheme, schema, table) abort
  let query = get(a:scheme, 'columns_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{table}', a:table, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_indexes(db, scheme, schema, table) abort
  let query = get(a:scheme, 'indexes_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{table}', a:table, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_primary_keys(db, scheme, schema, table) abort
  let query = get(a:scheme, 'primary_keys_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{table}', a:table, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_foreign_keys(db, scheme, schema, table) abort
  let query = get(a:scheme, 'foreign_keys_query_detail', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{table}', a:table, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_constraints(db, scheme, schema, table) abort
  let query = get(a:scheme, 'constraints_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{table}', a:table, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_parameters(db, scheme, schema, object_name) abort
  let query = get(a:scheme, 'parameters_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{object_name}', a:object_name, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction

function! db_ui#schemas#query_dependencies(db, scheme, schema, object_name) abort
  let query = get(a:scheme, 'dependencies_query', '')
  if empty(query)
    return []
  endif
  let query = substitute(query, '{schema}', a:schema, 'g')
  let query = substitute(query, '{object}', a:object_name, 'g')
  return db_ui#schemas#query(a:db, a:scheme, query)
endfunction
