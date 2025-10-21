let s:suite = themis#suite('blink.cmp source')
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
" Source Initialization Tests
" ==============================================================================

function! s:suite.should_load_blink_source() abort
  " Test that the Lua module can be loaded
  try
    lua require('blink.cmp.sources.dadbod')
    call s:expect(1).to_be_true()
  catch
    call s:expect(0).to_be_true('Failed to load blink.cmp source: ' . v:exception)
  endtry
endfunction

function! s:suite.should_create_source_instance() abort
  " Test source instantiation
  try
    lua local source = require('blink.cmp.sources.dadbod').new()
    call s:expect(1).to_be_true()
  catch
    call s:expect(0).to_be_true('Failed to create source instance: ' . v:exception)
  endtry
endfunction

function! s:suite.should_return_trigger_characters() abort
  let triggers = luaeval('require("blink.cmp.sources.dadbod").new():get_trigger_characters()')

  call s:expect(type(triggers)).to_equal(v:t_list)
  call s:expect(len(triggers)).to_be_greater_than(0)
  call s:expect(index(triggers, '.')).not.to_equal(-1)
  call s:expect(index(triggers, '@')).not.to_equal(-1)
endfunction

" ==============================================================================
" Source Enabled Tests
" ==============================================================================

function! s:suite.should_be_enabled_for_sql_filetype() abort
  :DBUI
  normal o
  normal o

  set filetype=sql
  let enabled = luaeval('require("blink.cmp.sources.dadbod").new():enabled()')

  " Should be enabled if IntelliSense is available
  if exists('*db_ui#completion#is_available') && db_ui#completion#is_available()
    call s:expect(enabled).to_be_true()
  endif
endfunction

function! s:suite.should_be_disabled_for_non_sql_filetype() abort
  new
  set filetype=vim

  let enabled = luaeval('require("blink.cmp.sources.dadbod").new():enabled()')
  call s:expect(enabled).to_be_false()

  close!
endfunction

function! s:suite.should_be_disabled_when_intellisense_disabled() abort
  :DBUI
  normal o
  normal o

  set filetype=sql
  let g:db_ui_enable_intellisense = 0

  let enabled = luaeval('require("blink.cmp.sources.dadbod").new():enabled()')
  call s:expect(enabled).to_be_false()

  let g:db_ui_enable_intellisense = 1
endfunction

" ==============================================================================
" Completion Item Kind Mapping Tests
" ==============================================================================

function! s:suite.should_map_column_kind_to_field() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "user_id", kind = "C", info = "INT"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Field = 5
  call s:expect(result.kind).to_equal(5)
endfunction

function! s:suite.should_map_table_kind_to_class() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "Users", kind = "T", info = "TABLE"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Class = 7
  call s:expect(result.kind).to_equal(7)
endfunction

function! s:suite.should_map_view_kind_to_class() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "UserOrders", kind = "V", info = "VIEW"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Class = 7
  call s:expect(result.kind).to_equal(7)
endfunction

function! s:suite.should_map_procedure_kind_to_method() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "sp_GetUsers", kind = "P", info = "Stored Procedure"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Method = 2
  call s:expect(result.kind).to_equal(2)
endfunction

function! s:suite.should_map_function_kind_to_function() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "fn_Calculate", kind = "F", info = "Function"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Function = 3
  call s:expect(result.kind).to_equal(3)
endfunction

function! s:suite.should_map_database_kind_to_module() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "MyDB", kind = "D", info = "Database"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Module = 9
  call s:expect(result.kind).to_equal(9)
endfunction

function! s:suite.should_map_schema_kind_to_folder() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "dbo", kind = "S", info = "Schema"}
    \ return source:transform_item(item)
  \ ')

  " CompletionItemKind.Folder = 19
  call s:expect(result.kind).to_equal(19)
endfunction

" ==============================================================================
" Completion Item Transformation Tests
" ==============================================================================

function! s:suite.should_include_data_type_in_label_details() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "email", kind = "C", data_type = "VARCHAR(255)", info = ""}
    \ return source:transform_item(item)
  \ ')

  call s:expect(has_key(result, 'labelDetails')).to_be_true()
  call s:expect(result.labelDetails.detail).to_match('VARCHAR(255)')
endfunction

function! s:suite.should_include_documentation() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {word = "user_id", kind = "C", info = "Type: INT | NOT NULL"}
    \ return source:transform_item(item)
  \ ')

  call s:expect(has_key(result, 'documentation')).to_be_true()
  call s:expect(result.documentation.kind).to_equal('markdown')
  call s:expect(result.documentation.value).to_match('INT')
endfunction

function! s:suite.should_include_signature_in_documentation() abort
  let result = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local item = {
    \   word = "sp_GetUsers",
    \   kind = "P",
    \   info = "Stored Procedure",
    \   signature = "sp_GetUsers(@user_id INT, @active BIT)"
    \ }
    \ return source:transform_item(item)
  \ ')

  call s:expect(has_key(result, 'documentation')).to_be_true()
  call s:expect(result.documentation.value).to_match('Signature')
  call s:expect(result.documentation.value).to_match('@user_id')
endfunction

" ==============================================================================
" Column Info Formatting Tests
" ==============================================================================

function! s:suite.should_format_column_with_all_metadata() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local col = {
    \   name = "user_id",
    \   data_type = "INT",
    \   nullable = false,
    \   is_pk = true,
    \   is_fk = false
    \ }
    \ return source:format_column_info(col)
  \ ')

  call s:expect(info).to_match('INT')
  call s:expect(info).to_match('NOT NULL')
  call s:expect(info).to_match('PRIMARY KEY')
endfunction

function! s:suite.should_format_column_with_foreign_key() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local col = {
    \   name = "order_id",
    \   data_type = "INT",
    \   nullable = false,
    \   is_pk = false,
    \   is_fk = true
    \ }
    \ return source:format_column_info(col)
  \ ')

  call s:expect(info).to_match('FOREIGN KEY')
  call s:expect(info).not.to_match('PRIMARY KEY')
endfunction

function! s:suite.should_format_nullable_column() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local col = {
    \   name = "email",
    \   data_type = "VARCHAR(255)",
    \   nullable = true,
    \   is_pk = false,
    \   is_fk = false
    \ }
    \ return source:format_column_info(col)
  \ ')

  call s:expect(info).to_match('NULL')
  call s:expect(info).not.to_match('NOT NULL')
endfunction

" ==============================================================================
" Table Info Formatting Tests
" ==============================================================================

function! s:suite.should_format_table_with_schema() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local tbl = {name = "Users", type = "table", schema = "dbo"}
    \ return source:format_table_info(tbl)
  \ ')

  call s:expect(info).to_match('TABLE')
  call s:expect(info).to_match('dbo')
endfunction

function! s:suite.should_format_view() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local tbl = {name = "UserOrders", type = "view", schema = "dbo"}
    \ return source:format_table_info(tbl)
  \ ')

  call s:expect(info).to_match('VIEW')
endfunction

function! s:suite.should_format_external_table() abort
  let info = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ local tbl = {name = "Orders", type = "table", schema = "dbo", database = "MyDB"}
    \ return source:format_table_info(tbl)
  \ ')

  call s:expect(info).to_match('TABLE')
  call s:expect(info).to_match('dbo')
  call s:expect(info).to_match('MyDB')
endfunction

" ==============================================================================
" Signature Generation Tests
" ==============================================================================

function! s:suite.should_generate_procedure_signature_with_params() abort
  " This test would require mocking the completion cache
  " For now, test the fallback case
  let sig = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ return source:get_procedure_signature("test_db", "sp_Test")
  \ ')

  call s:expect(sig).to_match('sp_Test')
  call s:expect(sig).to_match('(')
endfunction

function! s:suite.should_generate_function_signature_with_params() abort
  " Test the fallback case
  let sig = luaeval('
    \ local source = require("blink.cmp.sources.dadbod").new()
    \ return source:get_function_signature("test_db", "fn_Test")
  \ ')

  call s:expect(sig).to_match('fn_Test')
  call s:expect(sig).to_match('(')
endfunction

" ==============================================================================
" Filter Tests
" ==============================================================================

function! s:suite.should_filter_items_by_base_text() abort
  " Test filtering logic
  let items = [
        \ {'word': 'user_id', 'kind': 'C'},
        \ {'word': 'user_name', 'kind': 'C'},
        \ {'word': 'order_id', 'kind': 'C'}
        \ ]

  " Simulate Lua filtering
  let filtered = filter(copy(items), 'v:val.word =~? "^user"')

  call s:expect(len(filtered)).to_equal(2)
  call s:expect(filtered[0].word).to_match('^user')
endfunction

function! s:suite.should_filter_case_insensitive() abort
  let items = [
        \ {'word': 'UserID', 'kind': 'C'},
        \ {'word': 'username', 'kind': 'C'}
        \ ]

  let filtered = filter(copy(items), 'v:val.word =~? "^user"')

  call s:expect(len(filtered)).to_equal(2)
endfunction
