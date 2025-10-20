" ==============================================================================
" Filter Management Module for vim-dadbod-ui
" ==============================================================================
" Provides filtering capabilities for database objects at multiple levels:
" - Object type level (TABLES, VIEWS, PROCEDURES, FUNCTIONS)
" - Structural group level (Columns, Indexes, Keys, etc.)
"
" Filters are independent at each level and work on cached data without
" requiring database re-queries.
" ==============================================================================

" Storage for filters
" Format: { 'scope_key': { 'schema': '', 'object': '', 'column': '' } }
let s:filters = {}

" Storage for structural group filters (columns, indexes, etc.)
" Format: { 'scope_key': { 'column': '' } }
let s:object_filters = {}

" ==============================================================================
" Public API Functions
" ==============================================================================

" Initialize filter for a scope (creates empty structure if doesn't exist)
" @param scope: String - Unique scope identifier (e.g., 'server.db.tables')
function! db_ui#filter#init(scope) abort
  if !has_key(s:filters, a:scope)
    let s:filters[a:scope] = {
          \ 'schema': '',
          \ 'object': '',
          \ 'column': ''
          \ }
  endif
endfunction

" Set filter criteria for a scope
" @param scope: String - Scope identifier
" @param criteria: Dict - Filter criteria { 'schema': '', 'object': '', 'column': '' }
function! db_ui#filter#set(scope, criteria) abort
  call db_ui#filter#init(a:scope)

  " Merge criteria into existing filter
  let s:filters[a:scope] = extend(s:filters[a:scope], a:criteria)

  " Clean up empty values
  for key in keys(s:filters[a:scope])
    if empty(s:filters[a:scope][key])
      let s:filters[a:scope][key] = ''
    endif
  endfor
endfunction

" Get filter for a scope
" @param scope: String - Scope identifier
" @return: Dict - Filter criteria or empty dict if no filter exists
function! db_ui#filter#get(scope) abort
  if !has_key(s:filters, a:scope)
    return {}
  endif

  " Return only non-empty filter criteria
  let filter = {}
  for [key, value] in items(s:filters[a:scope])
    if !empty(value)
      let filter[key] = value
    endif
  endfor

  return filter
endfunction

" Check if a scope has an active filter
" @param scope: String - Scope identifier
" @return: Number - 1 if filter exists and is non-empty, 0 otherwise
function! db_ui#filter#has_filter(scope) abort
  let filter = db_ui#filter#get(a:scope)
  return !empty(filter)
endfunction

" Check if an item matches the filter criteria
" @param item: String - Item to check (e.g., '[dbo].[TableName]')
" @param filter: Dict - Filter criteria
" @return: Number - 1 if matches (should be shown), 0 if filtered out
function! db_ui#filter#matches(item, filter) abort
  if empty(a:filter)
    return 1
  endif

  " Parse item to extract schema and object name
  let parts = s:parse_item(a:item)

  " Check schema filter
  if has_key(a:filter, 'schema') && !empty(a:filter.schema)
    if !s:matches_pattern(parts.schema, a:filter.schema)
      return 0
    endif
  endif

  " Check object filter
  if has_key(a:filter, 'object') && !empty(a:filter.object)
    if !s:matches_pattern(parts.object, a:filter.object)
      return 0
    endif
  endif

  " Check column filter (for structural groups)
  if has_key(a:filter, 'column') && !empty(a:filter.column)
    if !s:matches_pattern(parts.column, a:filter.column)
      return 0
    endif
  endif

  return 1
endfunction

" Clear filter for a specific scope
" @param scope: String - Scope identifier
function! db_ui#filter#clear(scope) abort
  if has_key(s:filters, a:scope)
    call remove(s:filters, a:scope)
  endif
endfunction

" Clear all filters
function! db_ui#filter#clear_all() abort
  let s:filters = {}
  let s:object_filters = {}
endfunction

" Get list of all active filters
" @return: List - List of dicts with 'scope' and 'criteria' keys
function! db_ui#filter#list_active() abort
  let active = []

  for [scope, criteria] in items(s:filters)
    let filter = db_ui#filter#get(scope)
    if !empty(filter)
      call add(active, {
            \ 'scope': scope,
            \ 'criteria': filter
            \ })
    endif
  endfor

  return active
endfunction

" Count items that match filter
" @param items: List - List of items to filter
" @param filter: Dict - Filter criteria
" @return: Number - Count of matching items
function! db_ui#filter#count_matches(items, filter) abort
  if empty(a:filter)
    return len(a:items)
  endif

  let count = 0
  for item in a:items
    if db_ui#filter#matches(item, a:filter)
      let count += 1
    endif
  endfor

  return count
endfunction

" Filter a list of items
" @param items: List - Items to filter
" @param filter: Dict - Filter criteria
" @return: List - Filtered items
function! db_ui#filter#apply(items, filter) abort
  if empty(a:filter)
    return a:items
  endif

  let filtered = []
  for item in a:items
    if db_ui#filter#matches(item, a:filter)
      call add(filtered, item)
    endif
  endfor

  return filtered
endfunction

" ==============================================================================
" Private Helper Functions
" ==============================================================================

" Parse an item string to extract schema, object, and column parts
" @param item: String - Item in format '[schema].[object]' or plain text
" @return: Dict - Parsed parts { 'schema': '', 'object': '', 'column': '' }
function! s:parse_item(item) abort
  " Try to match [schema].[object] format
  let match_result = matchlist(a:item, '^\[\?\([^\]]*\)\]\?\.\[\?\([^\]]*\)\]\?$')

  if !empty(match_result) && len(match_result) >= 3
    return {
          \ 'schema': match_result[1],
          \ 'object': match_result[2],
          \ 'column': a:item
          \ }
  endif

  " Fallback for non-standard format or single-part names
  return {
        \ 'schema': '',
        \ 'object': a:item,
        \ 'column': a:item
        \ }
endfunction

" Check if text matches a pattern
" @param text: String - Text to check
" @param pattern: String - Pattern to match (regex or plain text)
" @return: Number - 1 if matches, 0 otherwise
function! s:matches_pattern(text, pattern) abort
  " Empty text should not match non-empty pattern
  if empty(a:text) && !empty(a:pattern)
    return 0
  endif

  " Empty pattern matches everything
  if empty(a:pattern)
    return 1
  endif

  " Use regex matching
  if g:db_ui_filter_use_regex
    " Add case-insensitive flag if needed
    let flags = g:db_ui_filter_case_sensitive ? '\C' : '\c'

    try
      return a:text =~# flags . a:pattern
    catch /.*/
      " If regex is invalid, fall back to plain text match
      return s:plain_text_match(a:text, a:pattern)
    endtry
  else
    " Use plain text matching
    return s:plain_text_match(a:text, a:pattern)
  endif
endfunction

" Plain text substring matching
" @param text: String - Text to search in
" @param pattern: String - Substring to find
" @return: Number - 1 if found, 0 otherwise
function! s:plain_text_match(text, pattern) abort
  if g:db_ui_filter_case_sensitive
    return stridx(a:text, a:pattern) >= 0
  else
    return stridx(tolower(a:text), tolower(a:pattern)) >= 0
  endif
endfunction

" ==============================================================================
" Utility Functions for UI
" ==============================================================================

" Format filter criteria for display
" @param filter: Dict - Filter criteria
" @return: String - Formatted filter string (e.g., '[schema:dbo, object:Emp*]')
function! db_ui#filter#format(filter) abort
  if empty(a:filter)
    return ''
  endif

  let parts = []

  if has_key(a:filter, 'schema') && !empty(a:filter.schema)
    call add(parts, 'schema:' . a:filter.schema)
  endif

  if has_key(a:filter, 'object') && !empty(a:filter.object)
    call add(parts, 'object:' . a:filter.object)
  endif

  if has_key(a:filter, 'column') && !empty(a:filter.column)
    call add(parts, 'column:' . a:filter.column)
  endif

  return empty(parts) ? '' : '[' . join(parts, ', ') . ']'
endfunction

" Build scope key for object type groups
" @param server_key: String - Server key name
" @param database_name: String - Database name
" @param object_type: String - Object type (tables, views, procedures, functions)
" @return: String - Scope key
function! db_ui#filter#build_scope(server_key, database_name, object_type) abort
  return a:server_key . '.' . a:database_name . '.' . a:object_type
endfunction

" Build scope key for structural groups
" @param server_key: String - Server key name
" @param database_name: String - Database name
" @param object_type: String - Object type
" @param object_name: String - Object name
" @param group_type: String - Structural group type (columns, indexes, etc.)
" @return: String - Scope key
function! db_ui#filter#build_structural_scope(server_key, database_name, object_type, object_name, group_type) abort
  return a:server_key . '.' . a:database_name . '.' . a:object_type . '.' . a:object_name . '.' . a:group_type
endfunction
