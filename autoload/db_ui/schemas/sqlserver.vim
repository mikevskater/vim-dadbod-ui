" autoload/db_ui/schemas/sqlserver.vim
" SQL Server Database Schema Module

" =============================================================================
" SQL SERVER: Database Queries
" =============================================================================

let s:databases_query = "
  \ SELECT 
  \   d.name,
  \   CAST(SUM(CASE WHEN mf.type = 0 THEN mf.size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb
  \ FROM sys.databases d
  \ LEFT JOIN sys.master_files mf ON d.database_id = mf.database_id
  \ GROUP BY d.name, d.database_id
  \ ORDER BY d.name"

" =============================================================================
" SQL SERVER: Object Queries
" =============================================================================

let s:tables_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(t.schema_id) AS schema_name,
  \   t.name AS table_name,
  \   CAST(t.is_ms_shipped AS VARCHAR(1)) AS is_system
  \ FROM sys.tables t
  \ ORDER BY schema_name, table_name"

let s:views_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(v.schema_id) AS schema_name,
  \   v.name AS view_name,
  \   CAST(v.is_ms_shipped AS VARCHAR(1)) AS is_system
  \ FROM sys.views v
  \ ORDER BY schema_name, view_name"

let s:procedures_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(p.schema_id) AS schema_name,
  \   p.name AS procedure_name,
  \   CAST(p.is_ms_shipped AS VARCHAR(1)) AS is_system
  \ FROM sys.procedures p
  \ ORDER BY schema_name, procedure_name"

let s:functions_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(o.schema_id) AS schema_name,
  \   o.name AS function_name,
  \   CAST(o.is_ms_shipped AS VARCHAR(1)) AS is_system,
  \   o.type_desc
  \ FROM sys.objects o
  \ WHERE o.type IN ('FN', 'IF', 'TF', 'AF')
  \ ORDER BY schema_name, function_name"

let s:types_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(t.schema_id) AS schema_name,
  \   t.name AS type_name,
  \   '0' AS is_system
  \ FROM sys.types t
  \ WHERE t.is_user_defined = 1
  \ ORDER BY schema_name, type_name"

let s:synonyms_by_schema_query = "
  \ SELECT 
  \   SCHEMA_NAME(s.schema_id) AS schema_name,
  \   s.name AS synonym_name,
  \   '0' AS is_system,
  \   s.base_object_name
  \ FROM sys.synonyms s
  \ ORDER BY schema_name, synonym_name"

" =============================================================================
" SQL SERVER: Object Metadata Queries
" =============================================================================

let s:object_definition_query = "
  \ SELECT OBJECT_DEFINITION(OBJECT_ID('{schema}.{object}'))"

let s:object_parameters_query = "
  \ SELECT 
  \   p.name AS parameter_name,
  \   TYPE_NAME(p.user_type_id) AS data_type,
  \   p.max_length,
  \   p.precision,
  \   p.scale,
  \   CAST(p.is_output AS VARCHAR(1)) AS is_output
  \ FROM sys.parameters p
  \ WHERE p.object_id = OBJECT_ID('{schema}.{object}')
  \ ORDER BY p.parameter_id"

let s:object_dependencies_query = "
  \ SELECT 
  \   OBJECT_SCHEMA_NAME(d.referencing_id) + '.' + OBJECT_NAME(d.referencing_id) AS referencing_object
  \ FROM sys.sql_expression_dependencies d
  \ WHERE d.referenced_id = OBJECT_ID('{schema}.{object}')
  \ ORDER BY referencing_object"

let s:object_references_query = "
  \ SELECT 
  \   OBJECT_SCHEMA_NAME(d.referenced_id) + '.' + OBJECT_NAME(d.referenced_id) AS referenced_object
  \ FROM sys.sql_expression_dependencies d
  \ WHERE d.referencing_id = OBJECT_ID('{schema}.{object}')
  \ ORDER BY referenced_object"

" =============================================================================
" SQL SERVER: Schema Definition
" =============================================================================

function! db_ui#schemas#sqlserver#get() abort
  " Get existing SQL Server schema definition (if any)
  " This maintains compatibility with existing vim-dadbod-ui code
  let base_schema = get(get(s:, 'schemas', {}), 'sqlserver', {})
  
  " Extend with our new queries and features
  return extend(base_schema, {
        \ 'databases_query': s:databases_query,
        \ 'tables_by_schema_query': s:tables_by_schema_query,
        \ 'views_by_schema_query': s:views_by_schema_query,
        \ 'procedures_by_schema_query': s:procedures_by_schema_query,
        \ 'functions_by_schema_query': s:functions_by_schema_query,
        \ 'types_by_schema_query': s:types_by_schema_query,
        \ 'synonyms_by_schema_query': s:synonyms_by_schema_query,
        \ 'object_definition_query': s:object_definition_query,
        \ 'object_parameters_query': s:object_parameters_query,
        \ 'object_dependencies_query': s:object_dependencies_query,
        \ 'object_references_query': s:object_references_query,
        \ 'supports_databases': 1,
        \ 'supports_procedures': 1,
        \ 'supports_functions': 1,
        \ 'supports_types': 1,
        \ 'supports_synonyms': 1,
        \ 'use_statement_template': "USE [{database}];\nGO\n\n",
        \ })
endfunction

" =============================================================================
" SQL SERVER: Custom Functions
" =============================================================================

" SQL Server doesn't need custom definition retrieval - uses default
" But we could add custom parsing if needed in the future

" Example of custom function (not currently used, but shows the pattern):
" function! db_ui#schemas#sqlserver#parse_procedure_params(results) abort
"   " Custom parsing for SQL Server procedure parameters
"   " Could handle SQL Server specific data types, etc.
"   return a:results
" endfunction