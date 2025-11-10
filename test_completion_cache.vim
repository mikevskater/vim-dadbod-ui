" Test script to verify completion cache is working
" Run with: nvim -u test_completion_cache.vim

" Enable debug mode
let g:db_ui_enable_intellisense = 1
let s:debug_enabled = 1

function! TestCompletionCache()
  echo "=== Testing Completion Cache ==="
  echo ""

  " 1. Check if functions exist
  echo "1. Checking if completion functions exist..."
  if !exists('*db_ui#completion#init_cache')
    echoerr "  ❌ db_ui#completion#init_cache does not exist!"
    return
  endif
  echo "  ✅ db_ui#completion#init_cache exists"

  if !exists('*db_ui#completion#get_completions')
    echoerr "  ❌ db_ui#completion#get_completions does not exist!"
    return
  endif
  echo "  ✅ db_ui#completion#get_completions exists"

  " 2. Check if we have a database connection
  echo ""
  echo "2. Checking database connection..."
  let db_key_name = get(b:, 'dbui_db_key_name', '')
  if empty(db_key_name)
    echoerr "  ❌ No database connection found (b:dbui_db_key_name is empty)"
    echo "  Please open a SQL buffer from DBUI first!"
    return
  endif
  echo "  ✅ Database key: " . db_key_name

  " 3. Get connection info
  echo ""
  echo "3. Getting connection info..."
  if !exists('*db_ui#get_conn_info')
    echoerr "  ❌ db_ui#get_conn_info does not exist!"
    return
  endif

  let db_info = db_ui#get_conn_info(db_key_name)
  if empty(db_info)
    echoerr "  ❌ No connection info found for: " . db_key_name
    return
  endif
  echo "  ✅ Connection info retrieved"
  echo "     URL: " . get(db_info, 'url', 'N/A')
  echo "     Scheme: " . get(db_info, 'scheme', 'N/A')
  echo "     Tables: " . len(get(db_info, 'tables', []))

  " 4. Enable debug mode
  echo ""
  echo "4. Enabling debug mode..."
  call db_ui#completion#toggle_debug()
  echo "  ✅ Debug mode enabled (check :messages for debug output)"

  " 5. Initialize cache
  echo ""
  echo "5. Initializing completion cache..."
  call db_ui#completion#init_cache(db_key_name)
  echo "  ✅ Cache initialization triggered"

  " Wait a moment for async fetch
  sleep 2

  " 6. Check cache status
  echo ""
  echo "6. Checking cache status..."
  call db_ui#completion#show_status()

  " 7. Test getting completions
  echo ""
  echo "7. Testing completion retrieval..."

  echo "  - Getting tables..."
  let tables = db_ui#completion#get_completions(db_key_name, 'tables')
  echo "    Found " . len(tables) . " tables"
  if len(tables) > 0
    echo "    Sample: " . get(tables[0], 'name', get(tables[0], 'word', 'Unknown'))
  endif

  echo "  - Getting views..."
  let views = db_ui#completion#get_completions(db_key_name, 'views')
  echo "    Found " . len(views) . " views"

  echo "  - Getting procedures..."
  let procedures = db_ui#completion#get_completions(db_key_name, 'procedures')
  echo "    Found " . len(procedures) . " procedures"

  echo "  - Getting functions..."
  let functions = db_ui#completion#get_completions(db_key_name, 'functions')
  echo "    Found " . len(functions) . " functions"

  " 8. Test column completions (if we have tables)
  if len(tables) > 0
    echo ""
    echo "8. Testing column completions..."
    let first_table = get(tables[0], 'name', get(tables[0], 'word', ''))
    if !empty(first_table)
      echo "  - Getting columns for: " . first_table
      let columns = db_ui#completion#get_completions(db_key_name, 'columns', first_table)
      echo "    Found " . len(columns) . " columns"
      if len(columns) > 0
        echo "    Sample: " . get(columns[0], 'name', get(columns[0], 'word', 'Unknown'))
      endif
    endif
  endif

  echo ""
  echo "=== Test Complete ==="
  echo ""
  echo "Check :messages for debug output"
  echo "Run :DBUICompletionStatus for detailed cache info"
endfunction

" Run the test
echo "Run :call TestCompletionCache() to test completion cache"
echo "Make sure you have opened a SQL buffer from DBUI first!"
