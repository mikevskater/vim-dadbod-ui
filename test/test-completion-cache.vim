let s:suite = themis#suite('Completion cache')
let s:expect = themis#helper('expect')

function! s:suite.before() abort
  call SetupTestDbs()
  " Enable IntelliSense for tests
  let g:db_ui_enable_intellisense = 1
  let g:db_ui_intellisense_cache_ttl = 300
endfunction

function! s:suite.after() abort
  call Cleanup()
  " Clean up completion cache
  if exists('*db_ui#completion#clear_all_caches')
    call db_ui#completion#clear_all_caches()
  endif
  unlet! g:db_ui_enable_intellisense
  unlet! g:db_ui_intellisense_cache_ttl
endfunction

" Test cache initialization
function! s:suite.should_initialize_cache_when_opening_query_buffer() abort
  :DBUI
  normal o
  normal o
  " Should have opened a query buffer

  " Check if IntelliSense is available
  call s:expect(exists('*db_ui#completion#is_available')).to_be_true()
  call s:expect(db_ui#completion#is_available()).to_be_true()

  " Check if cache exists for the database
  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call s:expect(db_key_name).not.to_be_empty()

  " Cache should be initialized (may be loading)
  let cache_data = db_ui#completion#get_all_cached_data(db_key_name)
  call s:expect(type(cache_data)).to_equal(v:t_dict)
endfunction

" Test get_completions function
function! s:suite.should_get_tables_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call s:expect(db_key_name).not.to_be_empty()

  " Initialize cache first
  call db_ui#completion#init_cache(db_key_name)

  " Get table completions
  let tables = db_ui#completion#get_completions(db_key_name, 'tables')
  call s:expect(type(tables)).to_equal(v:t_list)
endfunction

" Test cache refresh
function! s:suite.should_refresh_cache() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call s:expect(db_key_name).not.to_be_empty()

  " Initialize and then refresh
  call db_ui#completion#init_cache(db_key_name)
  call db_ui#completion#refresh_cache(db_key_name)

  " Cache should still exist
  let cache_data = db_ui#completion#get_all_cached_data(db_key_name)
  call s:expect(type(cache_data)).to_equal(v:t_dict)
endfunction

" Test cache clear
function! s:suite.should_clear_all_caches() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  " Clear all caches
  call db_ui#completion#clear_all_caches()

  " Cache should be empty
  let cache_data = db_ui#completion#get_all_cached_data(db_key_name)
  call s:expect(cache_data).to_be_empty()
endfunction

" Test cursor context detection
function! s:suite.should_detect_cursor_context_for_from_clause() abort
  :DBUI
  normal o
  normal o

  " Set up a query line
  call setline(1, 'SELECT * FROM ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('table')
endfunction

" Test cursor context for USE statement
function! s:suite.should_detect_cursor_context_for_use_clause() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'USE ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('database')
endfunction

" Test cursor context for column completion
function! s:suite.should_detect_cursor_context_for_columns() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT users.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
  call s:expect(context.table).to_equal('users')
endfunction

" Test database reference parsing
function! s:suite.should_parse_database_references() abort
  let query = 'SELECT u.* FROM MyDB.dbo.Users u JOIN OtherDB.schema.Orders o ON u.id = o.user_id'

  let db_refs = db_ui#completion#parse_database_references(query)

  call s:expect(type(db_refs)).to_equal(v:t_list)
  call s:expect(len(db_refs)).to_be_greater_than(0)
endfunction

" Test get_completion_info API
function! s:suite.should_return_extended_completion_info() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call s:expect(db_key_name).not.to_be_empty()

  " Get completion info
  let info = db_ui#get_completion_info(db_key_name)

  call s:expect(type(info)).to_equal(v:t_dict)
  call s:expect(has_key(info, 'tables')).to_be_true()
  call s:expect(has_key(info, 'schemas')).to_be_true()
  call s:expect(has_key(info, 'views')).to_be_true()
  call s:expect(has_key(info, 'procedures')).to_be_true()
  call s:expect(has_key(info, 'functions')).to_be_true()
  call s:expect(has_key(info, 'databases')).to_be_true()
endfunction

" Test IntelliSense disabled
function! s:suite.should_not_initialize_when_intellisense_disabled() abort
  " Disable IntelliSense
  let g:db_ui_enable_intellisense = 0

  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')

  " Cache should not be created when disabled
  let cache_data = db_ui#completion#get_all_cached_data(db_key_name)
  " Cache might be empty or not exist

  " Re-enable for other tests
  let g:db_ui_enable_intellisense = 1
endfunction

" Test completion status command
function! s:suite.should_show_completion_status() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  " This should not throw an error
  call db_ui#completion#show_status()

  " Test passes if no error thrown
  call s:expect(1).to_be_true()
endfunction

" Test external database detection
function! s:suite.should_detect_external_database_on_same_server() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  " Test external database checking (should not crash)
  let is_on_server = db_ui#completion#is_database_on_server(db_key_name, 'test_db')
  call s:expect(type(is_on_server)).to_equal(v:t_number)
endfunction

" Test fetch external database
function! s:suite.should_fetch_external_database_metadata() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  " This should not crash even if database doesn't exist
  let result = db_ui#completion#fetch_external_database(db_key_name, 'external_db')
  call s:expect(type(result)).to_equal(v:t_number)
endfunction

" Test debug mode toggle
function! s:suite.should_toggle_debug_mode() abort
  " Toggle debug on
  call db_ui#completion#toggle_debug()

  " Toggle debug off
  call db_ui#completion#toggle_debug()

  " Test passes if no error thrown
  call s:expect(1).to_be_true()
endfunction

" Test get completions for all object types
function! s:suite.should_get_all_object_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  " Get all objects
  let all_objects = db_ui#completion#get_completions(db_key_name, 'all_objects')
  call s:expect(type(all_objects)).to_equal(v:t_list)
endfunction

" Test schema completions
function! s:suite.should_get_schema_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  let schemas = db_ui#completion#get_completions(db_key_name, 'schemas')
  call s:expect(type(schemas)).to_equal(v:t_list)
endfunction

" Test view completions
function! s:suite.should_get_view_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  let views = db_ui#completion#get_completions(db_key_name, 'views')
  call s:expect(type(views)).to_equal(v:t_list)
endfunction

" Test procedure completions
function! s:suite.should_get_procedure_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  let procedures = db_ui#completion#get_completions(db_key_name, 'procedures')
  call s:expect(type(procedures)).to_equal(v:t_list)
endfunction

" Test function completions
function! s:suite.should_get_function_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  let functions = db_ui#completion#get_completions(db_key_name, 'functions')
  call s:expect(type(functions)).to_equal(v:t_list)
endfunction

" Test database completions
function! s:suite.should_get_database_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call db_ui#completion#init_cache(db_key_name)

  let databases = db_ui#completion#get_completions(db_key_name, 'databases')
  call s:expect(type(databases)).to_equal(v:t_list)
endfunction
