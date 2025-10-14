" autoload/db_ui/schemas/mysql.vim
" MySQL/MariaDB Database Schema Module

" =============================================================================
" MYSQL: Database Queries
" =============================================================================

let s:databases_query = "
  \ SELECT 
  \   schema_name,
  \   ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
  \ FROM information_schema.tables
  \ GROUP BY schema_name
  \ ORDER BY schema_name"

" =============================================================================
" MYSQL: Object Queries
" =============================================================================

let s:tables_by_schema_query = "
  \ SELECT 
  \   table_schema AS schema_name,
  \   table_name AS table_name,
  \   '0' AS is_system
  \ FROM information_schema.tables
  \ WHERE table_type = 'BASE TABLE'
  \   AND table_schema = DATABASE()
  \ ORDER BY schema_name, table_name"

let s:views_by_schema_query = "
  \ SELECT 
  \   table_schema AS schema_name,
  \   table_name AS view_name,
  \   '0' AS is_system
  \ FROM information_schema.views
  \ WHERE table_schema = DATABASE()
  \ ORDER BY schema_name, view_name"

let s:procedures_by_schema_query = "
  \ SELECT 
  \   routine_schema AS schema_name,
  \   routine_name AS procedure_name,
  \   '0' AS is_system
  \ FROM information_schema.routines
  \ WHERE routine_type = 'PROCEDURE'
  \   AND routine_schema = DATABASE()
  \ ORDER BY schema_name, procedure_name"

let s:functions_by_schema_query = "
  \ SELECT 
  \   routine_schema AS schema_name,
  \   routine_name AS function_name,
  \   '0' AS is_system
  \ FROM information_schema.routines
  \ WHERE routine_type = 'FUNCTION'
  \   AND routine_schema = DATABASE()
  \ ORDER BY schema_name, function_name"

" =============================================================================
" MYSQL: Object Definition Queries
" =============================================================================

" MySQL uses SHOW CREATE commands which vary by object type
let s:procedure_definition_query = "SHOW CREATE PROCEDURE `{schema}`.`{object}`"
let s:function_definition_query = "SHOW CREATE FUNCTION `{schema}`.`{object}`"
let s:view_definition_query = "SHOW CREATE VIEW `{schema}`.`{object}`"

let s:object_parameters_query = "
  \ SELECT 
  \   PARAMETER_NAME as parameter_name,
  \   DATA_TYPE as data_type,
  \   CHARACTER_MAXIMUM_LENGTH as max_length,
  \   NUMERIC_PRECISION as precision,
  \   NUMERIC_SCALE as scale,
  \   PARAMETER_MODE as mode
  \ FROM information_schema.parameters
  \ WHERE SPECIFIC_SCHEMA = '{schema}'
  \   AND SPECIFIC_NAME = '{object}'
  \ ORDER BY ORDINAL_POSITION"

" =============================================================================
" MYSQL: Schema Definition
" =============================================================================

function! db_ui#schemas#mysql#get() abort
  " Get existing MySQL schema definition (if any)
  let base_schema = get(get(s:, 'schemas', {}), 'mysql', {})
  
  " Extend with our new queries and features
  return extend(base_schema, {
        \ 'databases_query': s:databases_query,
        \ 'tables_by_schema_query': s:tables_by_schema_query,
        \ 'views_by_schema_query': s:views_by_schema_query,
        \ 'procedures_by_schema_query': s:procedures_by_schema_query,
        \ 'functions_by_schema_query': s:functions_by_schema_query,
        \ 'procedure_definition_query': s:procedure_definition_query,
        \ 'function_definition_query': s:function_definition_query,
        \ 'view_definition_query': s:view_definition_query,
        \ 'object_parameters_query': s:object_parameters_query,
        \ 'supports_databases': 1,
        \ 'supports_procedures': 1,
        \ 'supports_functions': 1,
        \ 'supports_types': 0,
        \ 'supports_synonyms': 0,
        \ 'use_statement_template': "USE `{database}`;\n\n",
        \ 'get_object_definition': function('db_ui#schemas#mysql#get_object_definition'),
        \ })
endfunction

" =============================================================================
" MYSQL: Custom Definition Retrieval
" =============================================================================

" MySQL needs special handling because it uses different SHOW commands
" for different object types
function! db_ui#schemas#mysql#get_object_definition(db, database_name, schema_name, object_name, object_type) abort
  " Determine which SHOW command to use based on object type
  if a:object_type ==# 'procedures'
    let query = s:procedure_definition_query
  elseif a:object_type ==# 'functions'
    let query = s:function_definition_query
  elseif a:object_type ==# 'views'
    let query = s:view_definition_query
  else
    return ['-- Definition not available for this object type']
  endif
  
  " Substitute parameters
  let query = db_ui#schemas#substitute_query_params(query, {
        \ 'schema': a:schema_name,
        \ 'object': a:object_name,
        \ })
  
  " Get the schema definition
  let mysql_scheme = db_ui#schemas#mysql#get()
  
  " Execute query in database context
  let results = db_ui#schemas#query_in_database(
        \ a:db, mysql_scheme, a:database_name, query)
  
  if empty(results) || len(results) < 2
    return ['-- Definition not found']
  endif
  
  " Parse MySQL SHOW CREATE output
  " Format: | Name | Create Statement | character_set | collation |
  " We want the Create Statement column (index 1 after splitting by tab)
  let parts = split(results[1], "\t")
  if len(parts) > 1
    " Split the definition into lines for better readability
    return split(parts[1], "\n")
  endif
  
  return results
endfunction