if exists('g:loaded_dbui')
  finish
endif
let g:loaded_dbui = 1

let g:db_ui_disable_progress_bar = get(g:, 'db_ui_disable_progress_bar', 0)
let g:db_ui_use_postgres_views = get(g:, 'db_ui_use_postgres_views', 1)
let g:db_ui_notification_width = get(g:, 'db_ui_notification_width', 40)
let g:db_ui_winwidth = get(g:, 'db_ui_winwidth', 40)
let g:db_ui_win_position = get(g:, 'db_ui_win_position', 'left')
let g:db_ui_default_query = get(g:, 'db_ui_default_query', 'SELECT * from "{table}" LIMIT 200;')
let g:db_ui_save_location = get(g:, 'db_ui_save_location', '~/.local/share/db_ui')
let g:db_ui_tmp_query_location = get(g:, 'db_ui_tmp_query_location', '')
let g:db_ui_dotenv_variable_prefix = get(g:, 'db_ui_dotenv_variable_prefix', 'DB_UI_')
let g:db_ui_env_variable_url = get(g:, 'db_ui_env_variable_url', 'DBUI_URL')
let g:db_ui_env_variable_name = get(g:, 'db_ui_env_variable_name', 'DBUI_NAME')
let g:db_ui_disable_mappings = get(g:, 'db_ui_disable_mappings', 0)
let g:db_ui_disable_mappings_dbui = get(g:, 'db_ui_disable_mappings_dbui', 0)
let g:db_ui_disable_mappings_dbout = get(g:, 'db_ui_disable_mappings_dbout', 0)
let g:db_ui_disable_mappings_sql = get(g:, 'db_ui_disable_mappings_sql', 0)
let g:db_ui_disable_mappings_javascript = get(g:, 'db_ui_disable_mappings_javascript', 0)
let g:db_ui_table_helpers = get(g:, 'db_ui_table_helpers', {})
let g:db_ui_auto_execute_table_helpers = get(g:, 'db_ui_auto_execute_table_helpers', 0)
let g:db_ui_show_help = get(g:, 'db_ui_show_help', 1)
let g:db_ui_use_nerd_fonts = get(g:, 'db_ui_use_nerd_fonts', 0)
let g:db_ui_execute_on_save = get(g:, 'db_ui_execute_on_save', 1)
let g:db_ui_force_echo_notifications = get(g:, 'db_ui_force_echo_notifications', 0)
let g:db_ui_disable_info_notifications = get(g:, 'db_ui_disable_info_notifications', 0)
let g:db_ui_use_nvim_notify = get(g:, 'db_ui_use_nvim_notify', 0)
let g:Db_ui_buffer_name_generator = get(g:, 'Db_ui_buffer_name_generator', 0)
let g:Db_ui_table_name_sorter = get(g:, 'Db_ui_table_name_sorter', 0)
let g:db_ui_debug = get(g:, 'db_ui_debug', 0)
let g:db_ui_hide_schemas = get(g:, 'db_ui_hide_schemas', [])
let g:db_ui_bind_param_pattern = get(g: , 'db_ui_bind_param_pattern', ':\w\+')
let g:db_ui_is_oracle_legacy = get(g:, 'db_ui_is_oracle_legacy', 0)
let g:db_ui_drawer_sections = get(g:, 'db_ui_drawer_sections', ['new_query', 'buffers', 'saved_queries', 'schemas'])

let s:dbui_icons = get(g:, 'db_ui_icons', {})
let s:expanded_icon = get(s:dbui_icons, 'expanded', '▾')
let s:collapsed_icon = get(s:dbui_icons, 'collapsed', '▸')
let s:expanded_icons = {}
let s:collapsed_icons = {}

if type(s:expanded_icon) !=? type('')
  let s:expanded_icons = s:expanded_icon
  let s:expanded_icon = '▾'
else
  silent! call remove(s:dbui_icons, 'expanded')
endif

if type(s:collapsed_icon) !=? type('')
  let s:collapsed_icons = s:collapsed_icon
  let s:collapsed_icon = '▸'
else
  silent! call remove(s:dbui_icons, 'collapsed')
endif

let g:db_ui_icons = {
      \ 'expanded': {
      \   'db': s:expanded_icon,
      \   'buffers': s:expanded_icon,
      \   'saved_queries': s:expanded_icon,
      \   'schemas': s:expanded_icon,
      \   'schema': s:expanded_icon,
      \   'tables': s:expanded_icon,
      \   'table': s:expanded_icon,
      \ },
      \ 'collapsed': {
      \   'db': s:collapsed_icon,
      \   'buffers': s:collapsed_icon,
      \   'saved_queries': s:collapsed_icon,
      \   'schemas': s:collapsed_icon,
      \   'schema': s:collapsed_icon,
      \   'tables': s:collapsed_icon,
      \   'table': s:collapsed_icon,
      \ },
      \ 'saved_query': '*',
      \ 'new_query': '+',
      \ 'tables': '~',
      \ 'buffers': '»',
      \ 'add_connection': '[+]',
      \ 'connection_ok': '✓',
      \ 'connection_error': '✕',
      \ }

if g:db_ui_use_nerd_fonts
  let g:db_ui_icons = {
        \ 'expanded': {
        \   'db': s:expanded_icon.' 󰆼',
        \   'buffers': s:expanded_icon.' ',
        \   'saved_queries': s:expanded_icon.' ',
        \   'schemas': s:expanded_icon.' ',
        \   'schema': s:expanded_icon.' 󰙅',
        \   'tables': s:expanded_icon.' 󰓱',
        \   'table': s:expanded_icon.' ',
        \ },
        \ 'collapsed': {
        \   'db': s:collapsed_icon.' 󰆼',
        \   'buffers': s:collapsed_icon.' ',
        \   'saved_queries': s:collapsed_icon.' ',
        \   'schemas': s:collapsed_icon.' ',
        \   'schema': s:collapsed_icon.' 󰙅',
        \   'tables': s:collapsed_icon.' 󰓱',
        \   'table': s:collapsed_icon.' ',
        \ },
        \ 'saved_query': '  ',
        \ 'new_query': '  󰓰',
        \ 'tables': '  󰓫',
        \ 'buffers': '  ',
        \ 'add_connection': '  󰆺',
        \ 'connection_ok': '✓',
        \ 'connection_error': '✕',
        \ }
endif

let g:db_ui_icons.expanded = extend(g:db_ui_icons.expanded, s:expanded_icons)
let g:db_ui_icons.collapsed = extend(g:db_ui_icons.collapsed, s:collapsed_icons)
silent! call remove(s:dbui_icons, 'expanded')
silent! call remove(s:dbui_icons, 'collapsed')
let g:db_ui_icons = extend(g:db_ui_icons, s:dbui_icons)

augroup dbui
  autocmd!
  autocmd BufRead,BufNewFile *.dbout set filetype=dbout
  autocmd BufReadPost *.dbout nested call db_ui#save_dbout(expand('<afile>'))
  autocmd FileType dbout,dbui autocmd BufEnter,WinEnter <buffer> stopinsert
augroup END

command! DBUI call db_ui#open('<mods>')
command! DBUIToggle call db_ui#toggle()
command! DBUIClose call db_ui#close()
command! DBUIAddConnection call db_ui#connections#add()
command! DBUIFindBuffer call db_ui#find_buffer()
command! DBUIRenameBuffer call db_ui#rename_buffer()
command! DBUILastQueryInfo call db_ui#print_last_query_info()

" ============================================================================
" Extended Icon System for Database Objects
" ============================================================================

" First, collect any user-defined icons from g:db_ui_icons
let s:dbui_icons = get(g:, 'db_ui_icons', {})

" Get the base expanded and collapsed icons
let s:expanded_icon = get(s:dbui_icons, 'expanded', '▾')
let s:collapsed_icon = get(s:dbui_icons, 'collapsed', '▸')
let s:expanded_icons = {}
let s:collapsed_icons = {}

" Handle cases where expanded/collapsed are dictionaries (per-item icons)
if type(s:expanded_icon) !=? type('')
  let s:expanded_icons = s:expanded_icon
  let s:expanded_icon = '▾'
else
  silent! call remove(s:dbui_icons, 'expanded')
endif

if type(s:collapsed_icon) !=? type('')
  let s:collapsed_icons = s:collapsed_icon
  let s:collapsed_icon = '▸'
else
  silent! call remove(s:dbui_icons, 'collapsed')
endif

" ============================================================================
" Base Icon Set (ASCII-compatible)
" ============================================================================

let g:db_ui_icons = {
      \ 'expanded': {
      \   'db': s:expanded_icon,
      \   'buffers': s:expanded_icon,
      \   'saved_queries': s:expanded_icon,
      \   'schemas': s:expanded_icon,
      \   'schema': s:expanded_icon,
      \   'tables': s:expanded_icon,
      \   'table': s:expanded_icon,
      \   'database': s:expanded_icon,
      \   'databases': s:expanded_icon,
      \   'views': s:expanded_icon,
      \   'view': s:expanded_icon,
      \   'procedures': s:expanded_icon,
      \   'procedure': s:expanded_icon,
      \   'functions': s:expanded_icon,
      \   'function': s:expanded_icon,
      \   'types': s:expanded_icon,
      \   'type': s:expanded_icon,
      \   'synonyms': s:expanded_icon,
      \   'synonym': s:expanded_icon,
      \ },
      \ 'collapsed': {
      \   'db': s:collapsed_icon,
      \   'buffers': s:collapsed_icon,
      \   'saved_queries': s:collapsed_icon,
      \   'schemas': s:collapsed_icon,
      \   'schema': s:collapsed_icon,
      \   'tables': s:collapsed_icon,
      \   'table': s:collapsed_icon,
      \   'database': s:collapsed_icon,
      \   'databases': s:collapsed_icon,
      \   'views': s:collapsed_icon,
      \   'view': s:collapsed_icon,
      \   'procedures': s:collapsed_icon,
      \   'procedure': s:collapsed_icon,
      \   'functions': s:collapsed_icon,
      \   'function': s:collapsed_icon,
      \   'types': s:collapsed_icon,
      \   'type': s:collapsed_icon,
      \   'synonyms': s:collapsed_icon,
      \   'synonym': s:collapsed_icon,
      \ },
      \ 'saved_query': '*',
      \ 'new_query': '+',
      \ 'tables': '~',
      \ 'buffers': '»',
      \ 'add_connection': '[+]',
      \ 'connection_ok': '✓',
      \ 'connection_error': '✕',
      \ 'database': 'DB',
      \ 'databases': '◉',
      \ 'views': '◈',
      \ 'procedures': '⚡',
      \ 'functions': 'ƒ',
      \ 'types': 'T',
      \ 'synonyms': '↔',
      \ 'action': '>',
      \ }

" ============================================================================
" Nerd Font Icon Set
" ============================================================================

if g:db_ui_use_nerd_fonts
  let g:db_ui_icons = {
        \ 'expanded': {
        \   'db': s:expanded_icon . ' ',
        \   'buffers': s:expanded_icon . ' ',
        \   'saved_queries': s:expanded_icon . ' ',
        \   'schemas': s:expanded_icon . ' ',
        \   'schema': s:expanded_icon . ' ',
        \   'tables': s:expanded_icon . ' ',
        \   'table': s:expanded_icon . ' ',
        \   'database': s:expanded_icon . ' ',
        \   'databases': s:expanded_icon . ' ',
        \   'views': s:expanded_icon . ' ',
        \   'view': s:expanded_icon . ' ',
        \   'procedures': s:expanded_icon . ' ',
        \   'procedure': s:expanded_icon . ' ',
        \   'functions': s:expanded_icon . ' λ',
        \   'function': s:expanded_icon . ' λ',
        \   'types': s:expanded_icon . ' ',
        \   'type': s:expanded_icon . ' ',
        \   'synonyms': s:expanded_icon . ' ',
        \   'synonym': s:expanded_icon . ' ',
        \ },
        \ 'collapsed': {
        \   'db': s:collapsed_icon . ' ',
        \   'buffers': s:collapsed_icon . ' ',
        \   'saved_queries': s:collapsed_icon . ' ',
        \   'schemas': s:collapsed_icon . ' ',
        \   'schema': s:collapsed_icon . ' ',
        \   'tables': s:collapsed_icon . ' ',
        \   'table': s:collapsed_icon . ' ',
        \   'database': s:collapsed_icon . ' ',
        \   'databases': s:collapsed_icon . ' ',
        \   'views': s:collapsed_icon . ' ',
        \   'view': s:collapsed_icon . ' ',
        \   'procedures': s:collapsed_icon . ' ',
        \   'procedure': s:collapsed_icon . ' ',
        \   'functions': s:collapsed_icon . ' λ',
        \   'function': s:collapsed_icon . ' λ',
        \   'types': s:collapsed_icon . ' ',
        \   'type': s:collapsed_icon . ' ',
        \   'synonyms': s:collapsed_icon . ' ',
        \   'synonym': s:collapsed_icon . ' ',
        \ },
        \ 'saved_query': '  ',
        \ 'new_query': '  ',
        \ 'tables': '  ',
        \ 'buffers': '  ',
        \ 'add_connection': '  ',
        \ 'connection_ok': '✓',
        \ 'connection_error': '✕',
        \ 'database': '  ',
        \ 'databases': '  ',
        \ 'views': '  ',
        \ 'procedures': '  ',
        \ 'functions': '  λ ',
        \ 'types': '  ',
        \ 'synonyms': '  ',
        \ 'action': '  ',
        \ }
endif

" ============================================================================
" Merge User-Defined Icons
" ============================================================================

" Apply user-defined expanded icons
let g:db_ui_icons.expanded = extend(g:db_ui_icons.expanded, s:expanded_icons)

" Apply user-defined collapsed icons
let g:db_ui_icons.collapsed = extend(g:db_ui_icons.collapsed, s:collapsed_icons)

" Remove expanded/collapsed from s:dbui_icons to prevent duplicate processing
silent! call remove(s:dbui_icons, 'expanded')
silent! call remove(s:dbui_icons, 'collapsed')

" Merge any remaining user-defined icons (for non-expandable items)
let g:db_ui_icons = extend(g:db_ui_icons, s:dbui_icons)

" ============================================================================
" Icon Helper Functions
" ============================================================================

" Get icon for a specific object type and state
function! db_ui#icons#get(object_type, is_expanded) abort
  if a:is_expanded
    return get(get(g:db_ui_icons, 'expanded', {}), a:object_type, 
      \ get(g:db_ui_icons, a:object_type, ''))
  else
    return get(get(g:db_ui_icons, 'collapsed', {}), a:object_type,
      \ get(g:db_ui_icons, a:object_type, ''))
  endif
endfunction

" Check if an object type has expandable icon support
function! db_ui#icons#is_expandable(object_type) abort
  return has_key(get(g:db_ui_icons, 'expanded', {}), a:object_type)
endfunction

" ============================================================================
" Database-Level Browsing Configuration
" ============================================================================

" Enable database-level navigation (multi-database support)
" When enabled, connections without a database specified will show a list
" of databases that can be expanded to view their objects
let g:db_ui_show_database_level = get(g:, 'db_ui_show_database_level', 1)

" List of databases to ignore/hide in the database browser
" Format: { 'scheme': ['db1', 'db2', ...] }
" Example: { 'sqlserver': ['ReportServer', 'ReportServerTempDB'] }
let g:db_ui_ignored_databases = get(g:, 'db_ui_ignored_databases', {})

" Default system databases to ignore (can be overridden by g:db_ui_ignored_databases)
if !exists('g:db_ui_default_ignored_databases')
  let g:db_ui_default_ignored_databases = {
    \ 'sqlserver': ['master', 'tempdb', 'model', 'msdb'],
    \ 'mysql': ['information_schema', 'mysql', 'performance_schema', 'sys'],
    \ }
endif

" ============================================================================
" System Object Display Configuration
" ============================================================================

" Show system objects (stored procedures, views, etc. created by the DBMS)
" System objects are typically prefixed with 'sys' or marked with is_ms_shipped flag
let g:db_ui_show_system_objects = get(g:, 'db_ui_show_system_objects', 0)

" Prefix to add to system object names when displayed
" Only used when g:db_ui_show_system_objects is enabled
let g:db_ui_system_object_prefix = get(g:, 'db_ui_system_object_prefix', '[SYS] ')

" ============================================================================
" Object Section Configuration
" ============================================================================

" Define which object types to display and in what order
" Available sections: 'tables', 'views', 'procedures', 'functions', 'types', 'synonyms'
" Note: Not all database types support all object types
let g:db_ui_object_sections = get(g:, 'db_ui_object_sections',
  \ ['tables', 'views', 'procedures', 'functions', 'types', 'synonyms'])

" ============================================================================
" USE Statement Configuration
" ============================================================================

" Automatically add USE <database> statement at the beginning of generated queries
" This ensures queries run in the correct database context
let g:db_ui_add_use_statement = get(g:, 'db_ui_add_use_statement', 1)

" Templates for USE statements by database type
" Available placeholders: {database}
if !exists('g:db_ui_use_statement_template')
  let g:db_ui_use_statement_template = {
    \ 'sqlserver': "USE [{database}];\nGO\n\n",
    \ 'mysql': "USE `{database}`;\n\n",
    \ 'mariadb': "USE `{database}`;\n\n",
    \ 'postgresql': "\\c {database}\n\n",
    \ 'postgres': "\\c {database}\n\n",
    \ }
endif

" ============================================================================
" Object Action Configuration
" ============================================================================

" Available actions for database objects (procedures, functions, etc.)
" These appear as sub-items when expanding an object
let g:db_ui_object_actions = get(g:, 'db_ui_object_actions',
  \ ['view_definition', 'script_create', 'script_alter', 'script_drop', 'script_execute'])

" Custom action labels (optional - defaults are used if not specified)
if !exists('g:db_ui_object_action_labels')
  let g:db_ui_object_action_labels = {
    \ 'view_definition': 'View Definition',
    \ 'script_create': 'Script as CREATE',
    \ 'script_alter': 'Script as ALTER',
    \ 'script_drop': 'Script as DROP',
    \ 'script_execute': 'Script as EXECUTE',
    \ }
endif

" ============================================================================
" Drawer Section Configuration
" ============================================================================

" Update the drawer sections to support the new structure
" This replaces the 'schemas' section with database-aware sections
" Note: The 'schemas' value is kept for backward compatibility but will
" be interpreted as 'database_objects' in the new system
let g:db_ui_drawer_sections = get(g:, 'db_ui_drawer_sections',
  \ ['new_query', 'buffers', 'saved_queries', 'database_objects'])

" ============================================================================
" Performance and Caching Configuration
" ============================================================================

" Cache object lists to improve performance (reduces database queries)
let g:db_ui_cache_object_lists = get(g:, 'db_ui_cache_object_lists', 1)

" How long to cache object lists (in seconds, 0 = forever until manual refresh)
let g:db_ui_cache_timeout = get(g:, 'db_ui_cache_timeout', 300)

" ============================================================================
" Object Filtering Configuration
" ============================================================================

" Enable filtering of object lists (for future implementation)
let g:db_ui_enable_object_filter = get(g:, 'db_ui_enable_object_filter', 0)

" Pattern-based object filtering (regex patterns)
" Example: { 'procedures': '^sp_user.*', 'tables': '^tbl.*' }
let g:db_ui_object_filter_patterns = get(g:, 'db_ui_object_filter_patterns', {})
