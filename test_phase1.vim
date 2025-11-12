" Test Phase 1: Cross-schema table search
" Usage: :source test_phase1.vim then :call TestPhase1()

function! TestPhase1() abort
  echo "=== Testing Phase 1: Cross-Schema Table Search ==="
  echo ""

  " 1. Check if DBUI connection exists
  echo "1. Checking DBUI connection..."
  if !exists('*db_ui#get_conn_info')
    echo "   ✗ FAIL: db_ui#get_conn_info not found"
    return
  endif

  " Get current buffer's connection
  let db_key = get(b:, 'dbui_db_key_name', '')
  if empty(db_key)
    echo "   ⚠ No connection in current buffer. Trying to find any active connection..."

    " Try to get first connection from DBUI
    if exists('*db_ui#connections_list')
      let connections = db_ui#connections_list()
      if !empty(connections)
        let db_key = connections[0].key_name
        echo "   → Using connection: " . db_key
      else
        echo "   ✗ FAIL: No DBUI connections found"
        return
      endif
    endif
  else
    echo "   ✓ Found connection: " . db_key
  endif

  " 2. Check if completion cache has data
  echo ""
  echo "2. Checking completion cache..."
  if !exists('*db_ui#completion#get_cache_info')
    echo "   ⚠ db_ui#completion#get_cache_info not available"
  else
    let cache_info = db_ui#completion#get_cache_info(db_key)
    if !empty(cache_info)
      echo "   ✓ Cache contains:"
      echo "     - Tables: " . len(get(cache_info, 'tables', []))
      echo "     - Views: " . len(get(cache_info, 'views', []))
      echo "     - Schemas: " . len(get(cache_info, 'schemas', []))
    else
      echo "   ⚠ Cache is empty or not initialized"
      echo "   → Try triggering completion first or expand objects in DBUI"
    endif
  endif

  " 3. Test find_table_schema function
  echo ""
  echo "3. Testing cross-schema search for 'Employees'..."

  " Create a test buffer to call the internal function
  let test_line = 'SELECT * FROM Employees.'
  let test_col = len(test_line)

  " Get cursor context (this will call find_table_schema internally)
  if exists('*db_ui#completion#get_cursor_context')
    let context = db_ui#completion#get_cursor_context(bufnr('%'), test_line, test_col)
    echo "   Context returned:"
    echo "     - type: " . get(context, 'type', 'NONE')
    echo "     - table: " . get(context, 'table', 'NONE')
    echo "     - schema: " . get(context, 'schema', 'NONE')

    if get(context, 'schema', '') != ''
      echo "   ✓ PASS: Schema auto-detected as '" . context.schema . "'"
    else
      echo "   ✗ FAIL: Schema is empty"
    endif
  else
    echo "   ✗ FAIL: db_ui#completion#get_cursor_context not found"
  endif

  " 4. Check messages for debug output
  echo ""
  echo "4. Check :messages for debug output showing table search"
  echo "   Look for lines like: '[DBUI-VIM] find_table_schema: Found Employees in schema dbo'"
  echo ""
  echo "=== Test Complete ==="
  echo ""
  echo "Next steps:"
  echo "1. Review :messages for debug output"
  echo "2. Try typing 'Employees.' in a SQL buffer and check if columns appear"
  echo "3. If columns don't appear, run :DBUIClearCache and try again"
endfunction

echo "Test script loaded. Run :call TestPhase1()"
