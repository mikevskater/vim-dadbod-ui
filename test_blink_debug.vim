" Blink.cmp Dadbod Source Debug Script
" This script checks why blink.cmp isn't calling the dadbod source

echo "\n=== Blink.cmp Dadbod Source Debug ==="
echo "\n"

" Test 1: Check if in SQL buffer
echo "1. Current filetype: " . &filetype
if &filetype ==# 'sql' || &filetype ==# 'mysql' || &filetype ==# 'plsql'
  echo "   ✓ PASS: Correct filetype for SQL completion"
else
  echo "   ✗ FAIL: Not a SQL filetype (current: " . &filetype . ")"
endif
echo "\n"

" Test 2: Check if buffer has database connection
echo "2. Database connection:"
if exists('b:dbui_db_key_name')
  echo "   b:dbui_db_key_name = " . b:dbui_db_key_name
  echo "   ✓ PASS: Buffer has database connection"
else
  echo "   ✗ FAIL: No b:dbui_db_key_name found"
  echo "   → Connect buffer with :DBUIChangeConnection"
endif
echo "\n"

" Test 3: Check if IntelliSense is enabled
echo "3. IntelliSense enabled:"
if exists('g:db_ui_enable_intellisense')
  echo "   g:db_ui_enable_intellisense = " . g:db_ui_enable_intellisense
  if g:db_ui_enable_intellisense == 1
    echo "   ✓ PASS: IntelliSense is enabled"
  else
    echo "   ✗ FAIL: IntelliSense is disabled"
    echo "   → Set: let g:db_ui_enable_intellisense = 1"
  endif
else
  echo "   ℹ INFO: Not set (defaults to 1)"
  echo "   ✓ PASS: Should be enabled by default"
endif
echo "\n"

" Test 4: Check if completion functions exist
echo "4. Completion functions:"
if exists('*db_ui#completion#is_available')
  echo "   ✓ db_ui#completion#is_available exists"
  let available = db_ui#completion#is_available()
  echo "   → Returns: " . available
  if available == 1
    echo "   ✓ PASS: Completion is available"
  else
    echo "   ✗ FAIL: Completion not available"
  endif
else
  echo "   ✗ FAIL: db_ui#completion#is_available not found"
endif
echo "\n"

if exists('*db_ui#completion#get_cursor_context')
  echo "   ✓ db_ui#completion#get_cursor_context exists"
else
  echo "   ✗ FAIL: db_ui#completion#get_cursor_context not found"
endif
echo "\n"

" Test 5: Check if blink.cmp is loaded
echo "5. Blink.cmp status:"
let blink_loaded = luaeval("pcall(require, 'blink.cmp')")
if blink_loaded
  echo "   ✓ PASS: blink.cmp module loaded"
else
  echo "   ✗ FAIL: blink.cmp not loaded"
endif
echo "\n"

" Test 6: Check if dadbod source module exists
echo "6. Dadbod source module:"
let dadbod_source_loaded = luaeval("pcall(require, 'blink.cmp.sources.dadbod')")
if dadbod_source_loaded
  echo "   ✓ PASS: blink.cmp.sources.dadbod module loaded"
else
  echo "   ✗ FAIL: blink.cmp.sources.dadbod not found"
  echo "   → Check if file exists at:"
  echo "     ~/.local/share/nvim/lazy/vim-dadbod-ui/lua/blink/cmp/sources/dadbod.lua"
endif
echo "\n"

" Test 7: Check blink sources configuration
echo "7. Blink sources config:"
lua << EOF
  local ok, blink = pcall(require, 'blink.cmp')
  if ok then
    -- Try to get config
    local config = blink.config or {}
    local sources = config.sources or {}
    local providers = sources.providers or {}

    if providers.dadbod then
      print("   ✓ PASS: dadbod source is configured")
      print("   → module: " .. (providers.dadbod.module or "not set"))
      print("   → name: " .. (providers.dadbod.name or "not set"))
    else
      print("   ✗ FAIL: dadbod source not in providers")
    end

    -- Check per_filetype
    local per_filetype = sources.per_filetype or {}
    if per_filetype.sql then
      print("   ✓ sql filetype sources: " .. vim.inspect(per_filetype.sql))
    else
      print("   ℹ INFO: No per_filetype.sql configuration")
    end
  else
    print("   ✗ FAIL: Could not load blink.cmp config")
  end
EOF
echo "\n"

" Test 8: Try to manually call the source's enabled() function
echo "8. Source enabled() test:"
lua << EOF
  local ok, source_mod = pcall(require, 'blink.cmp.sources.dadbod')
  if ok then
    local source = source_mod.new()
    local enabled = source:enabled()
    if enabled then
      print("   ✓ PASS: Source enabled() returns true")
    else
      print("   ✗ FAIL: Source enabled() returns false")
      print("   → Check filetype and db_ui_enable_intellisense")
    end
  else
    print("   ✗ FAIL: Could not create source instance")
  end
EOF
echo "\n"

" Test 9: Check trigger characters
echo "9. Trigger characters:"
lua << EOF
  local ok, source_mod = pcall(require, 'blink.cmp.sources.dadbod')
  if ok then
    local source = source_mod.new()
    local triggers = source:get_trigger_characters()
    print("   Triggers: " .. vim.inspect(triggers))
    if vim.tbl_contains(triggers, '.') then
      print("   ✓ PASS: '.' is a trigger character")
    else
      print("   ✗ FAIL: '.' not in triggers")
    end
  else
    print("   ✗ FAIL: Could not get trigger characters")
  end
EOF
echo "\n"

" Test 10: Manual completion test
echo "10. Manual completion test:"
if exists('b:dbui_db_key_name') && &filetype ==# 'sql'
  lua << EOF
    local ok, source_mod = pcall(require, 'blink.cmp.sources.dadbod')
    if ok then
      local source = source_mod.new()

      -- Create fake context
      local ctx = {
        line = 'SELECT * FROM Emp',
        cursor = {1, 17},
        bufnr = vim.api.nvim_get_current_buf()
      }

      -- Try to get completions
      local called = false
      source:get_completions(ctx, function(response)
        called = true
        local item_count = response.items and #response.items or 0
        print("   ✓ PASS: get_completions() executed")
        print("   → Returned " .. item_count .. " items")

        if item_count > 0 then
          print("   → First item: " .. (response.items[1].label or "unknown"))
          if response.items[1].label == "TEST_DBUI_COMPLETION" then
            print("   ✓✓ TEST COMPLETION FOUND!")
          end
        else
          print("   ⚠ WARNING: No completion items returned")
        end
      end)

      if not called then
        print("   ⚠ Callback not executed immediately (async?)")
      end
    else
      print("   ✗ FAIL: Could not load source module")
    end
EOF
else
  echo "   ⚠ SKIP: Not in connected SQL buffer"
  echo "   → Open a SQL buffer and connect it first"
endif
echo "\n"

echo "=== Debug Complete ==="
echo "\n"
echo "Next steps based on failures:"
echo "- If source not loaded: Check file path"
echo "- If enabled() is false: Check filetype and config"
echo "- If manual test fails: Check VimScript functions"
echo "- If manual test passes but real completion doesn't work: Check blink config"
echo "\n"
