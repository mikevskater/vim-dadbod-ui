" Direct test of completion system
" Run from a SQL query buffer: :source test_direct.vim

echo "=== Direct Completion Test ==="
echo ""

" Get current buffer's db key
let db_key = get(b:, 'dbui_db_key_name', '')
echo "Database key: " . (empty(db_key) ? 'NONE - Please open SQL buffer from DBUI!' : db_key)

if empty(db_key)
  finish
endif

echo ""
echo "Testing cache functions..."

" Test 1: Get tables
try
  let tables = db_ui#completion#get_completions(db_key, 'tables')
  echo "Tables count: " . len(tables)
  if len(tables) > 0
    echo "First 3 tables:"
    for i in range(min([3, len(tables)]))
      echo "  " . string(tables[i])
    endfor
  else
    echo "WARNING: No tables in cache!"
  endif
catch
  echo "ERROR getting tables: " . v:exception
endtry

echo ""

" Test 2: Test context detection
try
  let test_line = "SELECT * FROM dbo.E"
  let test_col = len(test_line)
  let bufnr = bufnr('%')

  echo "Testing context for: '" . test_line . "'"
  let context = db_ui#completion#get_cursor_context(bufnr, test_line, test_col)
  echo "Context result:"
  echo "  type: " . get(context, 'type', 'N/A')
  echo "  schema: " . get(context, 'schema', 'N/A')
  echo "  table: " . get(context, 'table', 'N/A')
  echo "  database: " . get(context, 'database', 'N/A')
catch
  echo "ERROR in context detection: " . v:exception
endtry

echo ""

" Test 3: Check if blink.cmp source is loaded
echo "Checking blink.cmp..."
try
  let has_blink = luaeval("pcall(require, 'blink.cmp.sources.dadbod')")
  echo "blink.cmp dadbod source: " . (has_blink ? 'LOADED' : 'NOT LOADED')
catch
  echo "Cannot check blink.cmp (Lua error or not installed)"
endtry

echo ""
echo "=== Test Complete ==="
echo ""
echo "If tables count is 0:"
echo "  1. Check cache status: :DBUICompletionStatus"
echo "  2. Refresh cache: :DBUIRefreshCompletion"
echo "  3. Enable debug: :call db_ui#completion#toggle_debug()"
echo "  4. Check :messages for errors"
