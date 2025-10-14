" autoload/db_ui/schemas/sqlite.vim
" SQLite Database Schema Module

" =============================================================================
" SQLITE: Object Queries
" =============================================================================
" Note: SQLite is file-based, no "database listing" concept
" SQLite doesn't support stored procedures, functions, or user-defined types

let s:tables_by_schema_query = "
  \ SELECT 
  \   'main' AS schema_name,
  \   name AS table_name,
  \   '0' AS is_system
  \ FROM sqlite_master
  \ WHERE type = 'table'
  \   AND name NOT LIKE 'sqlite_%'
  \ ORDER BY name"

let s:views_by_schema_query = "
  \ SELECT 
  \   'main' AS schema_name,
  \   name AS view_name,
  \   '0' AS is_system
  \ FROM sqlite_master
  \ WHERE type = 'view'
  \ ORDER BY name"

let s:triggers_by_schema_query = "
  \ SELECT 
  \   'main' AS schema_name,
  \   name AS trigger_name,
  \   '0' AS is_system
  \ FROM sqlite_master
  \ WHERE type = 'trigger'
  \ ORDER BY name"

let s:indexes_by_schema_query = "
  \ SELECT 
  \   'main' AS schema_name,
  \   name AS index_name,
  \   '0' AS is_system
  \ FROM sqlite_master
  \ WHERE type = 'index'
  \   AND name NOT LIKE 'sqlite_%'
  \ ORDER BY name"

" =============================================================================
" SQLITE: Object Definition Query
" =============================================================================

let s:object_definition_query = "
  \ SELECT sql
  \ FROM sqlite_master
  \ WHERE name = '{object}'"

" =============================================================================
" SQLITE: Schema Definition
" =============================================================================

function! db_ui#schemas#sqlite#get() abort
  " Get existing SQLite schema definition (if any)
  let base_schema = get(get(s:, 'schemas', {}), 'sqlite', {})
  
  " Extend with our new queries and features
  return extend(base_schema, {
        \ 'databases_query': '',
        \ 'tables_by_schema_query': s:tables_by_schema_query,
        \ 'views_by_schema_query': s:views_by_schema_query,
        \ 'triggers_by_schema_query': s:triggers_by_schema_query,
        \ 'indexes_by_schema_query': s:indexes_by_schema_query,
        \ 'object_definition_query': s:object_definition_query,
        \ 'supports_databases': 0,
        \ 'supports_procedures': 0,
        \ 'supports_functions': 0,
        \ 'supports_types': 0,
        \ 'supports_synonyms': 0,
        \ 'supports_triggers': 1,
        \ 'supports_indexes': 1,
        \ })
endfunction

" =============================================================================
" SQLITE: Helper Functions
" =============================================================================

" SQLite-specific helper to get table info
function! db_ui#schemas#sqlite#get_table_info(db, table_name) abort
  let sqlite_scheme = db_ui#schemas#sqlite#get()
  
  let query = 'PRAGMA table_info("' . a:table_name . '")'
  
  " Execute query
  return db_ui#schemas#query(a:db, sqlite_scheme, query)
endfunction

" SQLite-specific helper to get foreign keys
function! db_ui#schemas#sqlite#get_foreign_keys(db, table_name) abort
  let sqlite_scheme = db_ui#schemas#sqlite#get()
  
  let query = 'PRAGMA foreign_key_list("' . a:table_name . '")'
  
  " Execute query
  return db_ui#schemas#query(a:db, sqlite_scheme, query)
endfunction