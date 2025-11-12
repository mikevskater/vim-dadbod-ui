" Inspect completion cache
function! InspectCache() abort
  let db_key = get(b:, 'dbui_db_key_name', '')
  if empty(db_key)
    echo "No db_key_name in current buffer"
    return
  endif

  echo "=== Cache Inspection for: " . db_key . " ==="
  
  if exists('*db_ui#completion#get_cache_info')
    let cache = db_ui#completion#get_cache_info(db_key)
    if empty(cache)
      echo "Cache is empty or doesn't exist"
    else
      echo "Tables: " . len(get(cache, 'tables', []))
      if len(get(cache, 'tables', [])) > 0
        echo "First 3 tables:"
        for table in get(cache, 'tables', [])[:2]
          echo "  " . string(table)
        endfor
      endif
      
      echo "Views: " . len(get(cache, 'views', []))
      echo "Procedures: " . len(get(cache, 'procedures', []))
      echo "Functions: " . len(get(cache, 'functions', []))
      echo "Schemas: " . string(get(cache, 'schemas', []))
      echo "Databases: " . len(get(cache, 'databases', []))
    endif
  else
    echo "db_ui#completion#get_cache_info not found"
  endif
endfunction

command! InspectCache call InspectCache()
echo "Run :InspectCache to see cache contents"
