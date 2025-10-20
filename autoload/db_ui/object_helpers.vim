" SSMS-style object action helpers
" Provides SQL templates for actions on different database objects

let s:object_helpers = {}

" ==============================================================================
" SQL Server Object Helpers
" ==============================================================================

let s:object_helpers.sqlserver = {
      \ 'table': {
      \   'SELECT': 'SELECT TOP 100 * FROM [{schema}].[{table}]',
      \   'ALTER': 'SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(''[{schema}].[{table}]'')',
      \   'DROP': '-- DROP TABLE [{schema}].[{table}]',
      \   'DEPENDENCIES': "SELECT OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema, OBJECT_NAME(referencing_id) AS ReferencingObject, o.type_desc AS ReferencingType, OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema, OBJECT_NAME(referenced_id) AS ReferencedObject, o2.type_desc AS ReferencedType FROM sys.sql_expression_dependencies sed JOIN sys.objects o ON sed.referencing_id = o.object_id LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{table}]') OR sed.referenced_id = OBJECT_ID('[{schema}].[{table}]') ORDER BY ReferencingSchema, ReferencingObject",
      \ },
      \ 'view': {
      \   'SELECT': 'SELECT TOP 100 * FROM [{schema}].[{view}]',
      \   'ALTER': 'SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(''[{schema}].[{view}]'')',
      \   'DROP': '-- DROP VIEW [{schema}].[{view}]',
      \   'DEPENDENCIES': "SELECT OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema, OBJECT_NAME(referencing_id) AS ReferencingObject, o.type_desc AS ReferencingType, OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema, OBJECT_NAME(referenced_id) AS ReferencedObject, o2.type_desc AS ReferencedType FROM sys.sql_expression_dependencies sed JOIN sys.objects o ON sed.referencing_id = o.object_id LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{view}]') OR sed.referenced_id = OBJECT_ID('[{schema}].[{view}]') ORDER BY ReferencingSchema, ReferencingObject",
      \ },
      \ 'procedure': {
      \   'EXEC': 'EXEC [{schema}].[{procedure}]',
      \   'ALTER': 'SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(''[{schema}].[{procedure}]'')',
      \   'DROP': '-- DROP PROCEDURE [{schema}].[{procedure}]',
      \   'DEPENDENCIES': "SELECT OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema, OBJECT_NAME(referencing_id) AS ReferencingObject, o.type_desc AS ReferencingType, OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema, OBJECT_NAME(referenced_id) AS ReferencedObject, o2.type_desc AS ReferencedType FROM sys.sql_expression_dependencies sed JOIN sys.objects o ON sed.referencing_id = o.object_id LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{procedure}]') OR sed.referenced_id = OBJECT_ID('[{schema}].[{procedure}]') ORDER BY ReferencingSchema, ReferencingObject",
      \ },
      \ 'function': {
      \   'SELECT': 'SELECT * FROM [{schema}].[{function}]()',
      \   'ALTER': 'SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(''[{schema}].[{function}]'')',
      \   'DROP': '-- DROP FUNCTION [{schema}].[{function}]',
      \   'DEPENDENCIES': "SELECT OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema, OBJECT_NAME(referencing_id) AS ReferencingObject, o.type_desc AS ReferencingType, OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema, OBJECT_NAME(referenced_id) AS ReferencedObject, o2.type_desc AS ReferencedType FROM sys.sql_expression_dependencies sed JOIN sys.objects o ON sed.referencing_id = o.object_id LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{function}]') OR sed.referenced_id = OBJECT_ID('[{schema}].[{function}]') ORDER BY ReferencingSchema, ReferencingObject",
      \ },
      \ }

" ==============================================================================
" PostgreSQL Object Helpers
" ==============================================================================

let s:object_helpers.postgresql = {
      \ 'table': {
      \   'SELECT': 'SELECT * FROM "{schema}"."{table}" LIMIT 100',
      \   'ALTER': 'SELECT pg_get_viewdef(''{schema}.{table}''::regclass, true)',
      \   'DROP': '-- DROP TABLE "{schema}"."{table}"',
      \   'DEPENDENCIES': "SELECT DISTINCT dependent_ns.nspname as dependent_schema, dependent_view.relname as dependent_view, source_ns.nspname as source_schema, source_table.relname as source_table FROM pg_depend JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace WHERE source_ns.nspname = '{schema}' AND source_table.relname = '{table}' ORDER BY dependent_schema, dependent_view",
      \ },
      \ 'view': {
      \   'SELECT': 'SELECT * FROM "{schema}"."{view}" LIMIT 100',
      \   'ALTER': 'SELECT pg_get_viewdef(''{schema}.{view}''::regclass, true)',
      \   'DROP': '-- DROP VIEW "{schema}"."{view}"',
      \   'DEPENDENCIES': "SELECT DISTINCT dependent_ns.nspname as dependent_schema, dependent_view.relname as dependent_view, source_ns.nspname as source_schema, source_table.relname as source_table FROM pg_depend JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace WHERE source_ns.nspname = '{schema}' AND source_table.relname = '{view}' ORDER BY dependent_schema, dependent_view",
      \ },
      \ 'procedure': {
      \   'EXEC': 'CALL "{schema}"."{procedure}"()',
      \   'ALTER': 'SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = ''{procedure}'' AND pronamespace = ''{schema}''::regnamespace',
      \   'DROP': '-- DROP PROCEDURE "{schema}"."{procedure}"',
      \   'DEPENDENCIES': '',
      \ },
      \ 'function': {
      \   'SELECT': 'SELECT * FROM "{schema}"."{function}"()',
      \   'ALTER': 'SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = ''{function}'' AND pronamespace = ''{schema}''::regnamespace',
      \   'DROP': '-- DROP FUNCTION "{schema}"."{function}"',
      \   'DEPENDENCIES': '',
      \ },
      \ }

" ==============================================================================
" MySQL Object Helpers
" ==============================================================================

let s:object_helpers.mysql = {
      \ 'table': {
      \   'SELECT': 'SELECT * FROM `{schema}`.`{table}` LIMIT 100',
      \   'ALTER': 'SHOW CREATE TABLE `{schema}`.`{table}`',
      \   'DROP': '-- DROP TABLE `{schema}`.`{table}`',
      \   'DEPENDENCIES': '',
      \ },
      \ 'view': {
      \   'SELECT': 'SELECT * FROM `{schema}`.`{view}` LIMIT 100',
      \   'ALTER': 'SHOW CREATE VIEW `{schema}`.`{view}`',
      \   'DROP': '-- DROP VIEW `{schema}`.`{view}`',
      \   'DEPENDENCIES': '',
      \ },
      \ 'procedure': {
      \   'EXEC': 'CALL `{schema}`.`{procedure}`()',
      \   'ALTER': 'SHOW CREATE PROCEDURE `{schema}`.`{procedure}`',
      \   'DROP': '-- DROP PROCEDURE `{schema}`.`{procedure}`',
      \   'DEPENDENCIES': '',
      \ },
      \ 'function': {
      \   'SELECT': 'SELECT `{schema}`.`{function}`()',
      \   'ALTER': 'SHOW CREATE FUNCTION `{schema}`.`{function}`',
      \   'DROP': '-- DROP FUNCTION `{schema}`.`{function}`',
      \   'DEPENDENCIES': '',
      \ },
      \ }

" MariaDB uses same helpers as MySQL
let s:object_helpers.mariadb = s:object_helpers.mysql

" ==============================================================================
" Public API
" ==============================================================================

function! db_ui#object_helpers#get(scheme, object_type) abort
  let scheme = tolower(a:scheme)
  if !has_key(s:object_helpers, scheme)
    return {}
  endif

  let object_type = a:object_type ==# 'tables' ? 'table' : a:object_type
  let object_type = substitute(object_type, 's$', '', '')  " Remove trailing 's'

  if !has_key(s:object_helpers[scheme], object_type)
    return {}
  endif

  return s:object_helpers[scheme][object_type]
endfunction

function! db_ui#object_helpers#substitute_vars(template, vars) abort
  let result = a:template
  for [key, value] in items(a:vars)
    let result = substitute(result, '{'.key.'}', value, 'g')
  endfor
  return result
endfunction

function! db_ui#object_helpers#get_action(scheme, object_type, action, vars) abort
  let helpers = db_ui#object_helpers#get(a:scheme, a:object_type)
  if empty(helpers) || !has_key(helpers, a:action)
    return ''
  endif

  let template = helpers[a:action]
  return db_ui#object_helpers#substitute_vars(template, a:vars)
endfunction
