" Debug script to check scheme_info and db_info
" Run from SQL query buffer: :source debug_scheme_info.vim

echo "=== Scheme Info Debug ==="
echo ""

let db_key = get(b:, 'dbui_db_key_name', '')
if empty(db_key)
  echoerr "Not in a DBUI query buffer!"
  finish
endif

echo "Database key: " . db_key
echo ""

" Get connection info
try
  let db_info = db_ui#get_conn_info(db_key)
  echo "db_info keys: " . string(keys(db_info))
  echo "  url: " . get(db_info, 'url', 'N/A')
  echo "  scheme: " . get(db_info, 'scheme', 'N/A')
  echo "  connected: " . get(db_info, 'connected', 'N/A')
  echo "  tables count: " . len(get(db_info, 'tables', []))
  echo ""
catch
  echoerr "Error getting db_info: " . v:exception
endtry

" Check if scheme exists
let scheme = get(db_info, 'scheme', '')
echo "Checking scheme: '" . scheme . "'"

if empty(scheme)
  echoerr "ERROR: scheme is empty in db_info!"
  finish
endif

" Try to get scheme_info
try
  if exists('*db_ui#schemas#get')
    let scheme_info = db_ui#schemas#get(scheme)
    echo "scheme_info result: " . (empty(scheme_info) ? 'EMPTY!' : 'Found')

    if !empty(scheme_info)
      echo "scheme_info keys: " . string(keys(scheme_info))
    else
      echo ""
      echo "ERROR: db_ui#schemas#get('" . scheme . "') returned empty!"
      echo ""
      echo "Available schemes:"
      for s in ['sqlserver', 'postgres', 'mysql', 'postgresql']
        let test_info = db_ui#schemas#get(s)
        echo "  " . s . ": " . (empty(test_info) ? 'EMPTY' : 'OK')
      endfor
    endif
  else
    echoerr "ERROR: db_ui#schemas#get function doesn't exist!"
  endif
catch
  echoerr "Error getting scheme_info: " . v:exception
endtry

echo ""

" Try to call query_tables directly
echo "Testing db_ui#schemas#query_tables..."
try
  if exists('*db_ui#schemas#query_tables')
    if !empty(scheme_info)
      echo "Calling query_tables(db_info, scheme_info)..."
      let tables = db_ui#schemas#query_tables(db_info, scheme_info)
      echo "Result: " . len(tables) . " tables"

      if len(tables) > 0
        echo "First table: " . string(tables[0])
      endif
    else
      echo "Cannot test: scheme_info is empty"
    endif
  else
    echo "ERROR: db_ui#schemas#query_tables doesn't exist!"
  endif
catch
  echoerr "Error calling query_tables: " . v:exception
  echo "Exception details: " . v:throwpoint
endtry

echo ""
echo "=== Debug Complete ==="
