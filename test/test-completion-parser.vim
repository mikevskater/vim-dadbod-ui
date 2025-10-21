let s:suite = themis#suite('Completion parser')
let s:expect = themis#helper('expect')

function! s:suite.before() abort
  call SetupTestDbs()
  let g:db_ui_enable_intellisense = 1
endfunction

function! s:suite.after() abort
  call Cleanup()
  if exists('*db_ui#completion#clear_all_caches')
    call db_ui#completion#clear_all_caches()
  endif
  unlet! g:db_ui_enable_intellisense
endfunction

" ==============================================================================
" Table Alias Parsing Tests
" ==============================================================================

function! s:suite.should_parse_simple_alias() abort
  let query = 'SELECT * FROM Users u WHERE u.id = 1'
  let aliases = s:call_parse_aliases(query)

  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(aliases['u'].table).to_equal('Users')
endfunction

function! s:suite.should_parse_alias_with_as_keyword() abort
  let query = 'SELECT * FROM Users AS u WHERE u.id = 1'
  let aliases = s:call_parse_aliases(query)

  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(aliases['u'].table).to_equal('Users')
endfunction

function! s:suite.should_parse_multiple_aliases() abort
  let query = 'SELECT u.*, o.* FROM Users u JOIN Orders o ON u.id = o.user_id'
  let aliases = s:call_parse_aliases(query)

  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(has_key(aliases, 'o')).to_be_true()
  call s:expect(aliases['u'].table).to_equal('Users')
  call s:expect(aliases['o'].table).to_equal('Orders')
endfunction

function! s:suite.should_parse_schema_qualified_alias() abort
  let query = 'SELECT u.* FROM dbo.Users u'
  let aliases = s:call_parse_aliases(query)

  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(aliases['u'].table).to_equal('Users')
  call s:expect(aliases['u'].schema).to_equal('dbo')
endfunction

function! s:suite.should_parse_database_schema_qualified_alias() abort
  let query = 'SELECT u.* FROM MyDB.dbo.Users u'
  let aliases = s:call_parse_aliases(query)

  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(aliases['u'].table).to_equal('Users')
  call s:expect(aliases['u'].schema).to_equal('dbo')
  call s:expect(aliases['u'].database).to_equal('MyDB')
endfunction

function! s:suite.should_parse_left_join_alias() abort
  let query = 'SELECT * FROM Users u LEFT JOIN Orders o ON u.id = o.user_id'
  let aliases = s:call_parse_aliases(query)

  call s:expect(len(aliases)).to_equal(2)
  call s:expect(has_key(aliases, 'u')).to_be_true()
  call s:expect(has_key(aliases, 'o')).to_be_true()
endfunction

" ==============================================================================
" External Database Reference Parsing Tests
" ==============================================================================

function! s:suite.should_detect_external_database_reference() abort
  let query = 'SELECT * FROM OtherDB.dbo.Users'
  let db_refs = db_ui#completion#parse_database_references(query)

  call s:expect(len(db_refs)).to_be_greater_than(0)
  call s:expect(index(db_refs, 'OtherDB')).not.to_equal(-1)
endfunction

function! s:suite.should_detect_multiple_external_database_references() abort
  let query = 'SELECT u.*, o.* FROM MyDB.dbo.Users u JOIN ReportDB.dbo.Orders o ON u.id = o.user_id'
  let db_refs = db_ui#completion#parse_database_references(query)

  call s:expect(len(db_refs)).to_be_greater_than_or_equal(2)
endfunction

function! s:suite.should_not_detect_keywords_as_databases() abort
  let query = 'SELECT * FROM Users WHERE id = 1'
  let db_refs = db_ui#completion#parse_database_references(query)

  " Should not include SQL keywords
  call s:expect(index(db_refs, 'SELECT')).to_equal(-1)
  call s:expect(index(db_refs, 'FROM')).to_equal(-1)
  call s:expect(index(db_refs, 'WHERE')).to_equal(-1)
endfunction

function! s:suite.should_not_detect_functions_as_databases() abort
  let query = 'SELECT COUNT(*) FROM Users'
  let db_refs = db_ui#completion#parse_database_references(query)

  " Should not include function names
  call s:expect(index(db_refs, 'COUNT')).to_equal(-1)
endfunction

" ==============================================================================
" Context Detection Tests
" ==============================================================================

function! s:suite.should_detect_table_context_after_from() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT * FROM ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('table')
endfunction

function! s:suite.should_detect_database_context_after_use() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'USE ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('database')
endfunction

function! s:suite.should_detect_procedure_context_after_exec() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'EXEC ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('procedure')
endfunction

function! s:suite.should_detect_column_context_for_table_qualifier() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT Users.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
  call s:expect(context.table).to_equal('Users')
endfunction

function! s:suite.should_detect_column_context_for_alias_qualifier() abort
  :DBUI
  normal o
  normal o

  call setline(1, ['SELECT u.* FROM Users u WHERE u.'])
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
  " Note: alias resolution requires multi-line support, so table may not be resolved here
endfunction

function! s:suite.should_detect_schema_context_after_database_dot() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT * FROM MyDB.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('schema')
  call s:expect(context.database).to_equal('MyDB')
endfunction

function! s:suite.should_detect_table_context_after_database_schema_dot() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT * FROM MyDB.dbo.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('table')
  call s:expect(context.database).to_equal('MyDB')
  call s:expect(context.schema).to_equal('dbo')
endfunction

function! s:suite.should_detect_column_context_for_schema_table() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT dbo.Users.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
  call s:expect(context.schema).to_equal('dbo')
  call s:expect(context.table).to_equal('Users')
endfunction

function! s:suite.should_detect_column_context_for_database_schema_table() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT MyDB.dbo.Users.')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
  call s:expect(context.database).to_equal('MyDB')
  call s:expect(context.schema).to_equal('dbo')
  call s:expect(context.table).to_equal('Users')
endfunction

function! s:suite.should_detect_parameter_context() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'EXEC sp_Test @')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('parameter')
endfunction

function! s:suite.should_detect_column_context_in_where_clause() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT * FROM Users WHERE ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column_or_function')
endfunction

function! s:suite.should_detect_column_context_in_order_by() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT * FROM Users ORDER BY ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
endfunction

function! s:suite.should_detect_column_context_in_group_by() abort
  :DBUI
  normal o
  normal o

  call setline(1, 'SELECT COUNT(*) FROM Users GROUP BY ')
  normal $

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  call s:expect(context.type).to_equal('column')
endfunction

" ==============================================================================
" Multi-line Query Support Tests
" ==============================================================================

function! s:suite.should_parse_aliases_from_multiline_query() abort
  :DBUI
  normal o
  normal o

  call setline(1, [
        \ 'SELECT u.name, o.total',
        \ 'FROM Users u',
        \ 'JOIN Orders o ON u.id = o.user_id',
        \ 'WHERE u.'
        \ ])
  normal G$

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))

  " Should have parsed aliases from previous lines
  call s:expect(context.type).to_equal('column')
  call s:expect(has_key(context.aliases, 'u')).to_be_true()
  call s:expect(has_key(context.aliases, 'o')).to_be_true()
endfunction

function! s:suite.should_detect_external_databases_from_multiline_query() abort
  :DBUI
  normal o
  normal o

  call setline(1, [
        \ 'SELECT u.name',
        \ 'FROM MyDB.dbo.Users u',
        \ 'JOIN OtherDB.dbo.Orders o ON u.id = o.user_id',
        \ 'WHERE '
        \ ])
  normal G$

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))

  " Should have detected external databases
  call s:expect(len(context.external_databases)).to_be_greater_than(0)
endfunction

" ==============================================================================
" External Database Completions Tests
" ==============================================================================

function! s:suite.should_get_external_database_completions() abort
  :DBUI
  normal o
  normal o

  let db_key_name = get(b:, 'dbui_db_key_name', '')
  call s:expect(db_key_name).not.to_be_empty()

  " This should not crash even if external DB doesn't exist
  let ext_completions = db_ui#completion#get_external_completions(db_key_name, 'external_db', 'tables')
  call s:expect(type(ext_completions)).to_equal(v:t_list)
endfunction

" ==============================================================================
" Helper Functions
" ==============================================================================

" Helper to call internal parse_table_aliases function via get_cursor_context
function! s:call_parse_aliases(query) abort
  " We need to call this indirectly since s:parse_table_aliases is script-local
  " Create a temporary buffer with the query
  new
  call setline(1, split(a:query, "\n"))
  normal G$

  let context = db_ui#completion#get_cursor_context(bufnr(''), getline('.'), col('.'))
  let aliases = context.aliases

  " Clean up
  close!

  return aliases
endfunction
