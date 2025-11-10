" Debug script to trace blink.cmp completion pipeline
" Run with: :source debug_blink_completions.vim
" Then run: :call DebugBlinkCompletions()

function! DebugBlinkCompletions()
  echo "=== Debugging Blink Completions ==="
  echo ""

  " 1. Check buffer variables
  echo "1. Buffer Variables:"
  let db_key_name = get(b:, 'dbui_db_key_name', '')
  if empty(db_key_name)
    echoerr "  ❌ No database connection (b:dbui_db_key_name is empty)"
    echo "  Please open a SQL buffer from DBUI first!"
    return
  endif
  echo "  ✅ Database key: " . db_key_name
  echo ""

  " 2. Check if completion functions exist
  echo "2. Checking completion functions..."
  if !exists('*db_ui#completion#get_completions')
    echoerr "  ❌ db_ui#completion#get_completions does not exist!"
    return
  endif
  echo "  ✅ db_ui#completion#get_completions exists"
  echo ""

  " 3. Check cache status
  echo "3. Cache Status:"
  if exists('*db_ui#completion#show_status')
    call db_ui#completion#show_status()
  else
    echo "  ⚠️  db_ui#completion#show_status not available"
  endif
  echo ""

  " 4. Test getting tables
  echo "4. Testing table retrieval..."
  let tables = db_ui#completion#get_completions(db_key_name, 'tables')
  echo "  Tables count: " . len(tables)
  if len(tables) > 0
    echo "  ✅ Found tables!"
    echo "  Sample tables:"
    for i in range(min([5, len(tables)]))
      let table = tables[i]
      if type(table) == type({})
        echo "    - " . get(table, 'name', 'Unknown')
      else
        echo "    - " . string(table)
      endif
    endfor
  else
    echo "  ❌ No tables found in cache!"
  endif
  echo ""

  " 5. Test context parsing for "dbo.E"
  echo "5. Testing context parsing for 'dbo.E'..."
  let test_line = "SELECT * FROM dbo.E"
  let test_col = len(test_line)
  let bufnr = bufnr('%')

  if !exists('*db_ui#completion#get_cursor_context')
    echoerr "  ❌ db_ui#completion#get_cursor_context does not exist!"
    return
  endif

  let context = db_ui#completion#get_cursor_context(bufnr, test_line, test_col)
  echo "  Context type: " . get(context, 'type', 'N/A')
  echo "  Schema: " . get(context, 'schema', 'N/A')
  echo "  Table: " . get(context, 'table', 'N/A')
  echo "  Database: " . get(context, 'database', 'N/A')
  echo "  Full context: " . string(context)
  echo ""

  " 6. Test what blink.cmp would get
  echo "6. Simulating blink.cmp request..."
  let context_type = get(context, 'type', 'all_objects')
  echo "  Would request: " . context_type

  if context_type == 'table'
    let schema = get(context, 'schema', '')
    echo "  Schema filter: " . (empty(schema) ? 'none' : schema)
  endif
  echo ""

  " 7. Check if IntelliSense is enabled
  echo "7. IntelliSense Configuration:"
  echo "  g:db_ui_enable_intellisense = " . get(g:, 'db_ui_enable_intellisense', 1)

  if exists('*db_ui#completion#is_available')
    echo "  IntelliSense available: " . db_ui#completion#is_available()
  endif
  echo ""

  echo "=== Debug Complete ==="
  echo ""
  echo "If tables are found but not showing in blink.cmp:"
  echo "  1. Check :messages for errors"
  echo "  2. Run :call db_ui#completion#toggle_debug() for more logging"
  echo "  3. Check blink.cmp configuration"
endfunction

echo "Run :call DebugBlinkCompletions() to debug completion issues"
