# Native Neovim Test Suite

## Overview

This is a **native Neovim test framework** designed specifically for testing vim-dadbod-ui's IntelliSense and database features. Unlike traditional Vim test frameworks (like vim-themis), this runs **inside a live Neovim instance** with full access to:

- ✅ Lua code
- ✅ Buffer manipulation
- ✅ blink.cmp integration
- ✅ Real plugin environment
- ✅ All Neovim features

## Why This Approach?

vim-dadbod-ui's IntelliSense features are **Neovim-specific**:
- Phase 1-2: VimL + Lua integration
- Phase 4: Pure Lua blink.cmp source

Testing these with Vim-based frameworks doesn't work because:
- ❌ Vim doesn't have Lua
- ❌ Can't test blink.cmp in Vim
- ❌ Buffer/window APIs differ
- ❌ Path handling issues on Windows

**Solution**: Run tests in actual Neovim where the code will be used!

---

## Running Tests

### Quick Start

Open Neovim and run any of these commands:

```vim
" Run all tests (connections, SSMS features, cache, parser, blink.cmp)
:DBUITestFullSuite

" Run only IntelliSense tests
:DBUITestIntellisense

" Run only connection tests
:DBUITestConnections

" Run all database connection type tests
:DBUITestAllConnections

" Run specific database type tests
:DBUITestConnection sqlserver
:DBUITestConnection mysql
:DBUITestConnection postgresql
:DBUITestConnection sqlite
:DBUITestConnection bigquery
:DBUITestConnection oracle
```

### What Happens

1. **Tests execute** in your Neovim instance
2. **Results appear** in a split window
3. **File is saved** to `~/.local/share/nvim/dadbod_ui/test_results_*.txt`
4. **Summary shows**: Total, Passed, Failed, Success Rate

---

## Test Output Example

```
================================================================================
vim-dadbod-ui Full Test Suite
================================================================================

Date: 2025-10-21 19:30:15

================================================================================
Running: IntelliSense Cache
================================================================================

  ✅ test_intellisense_is_enabled
  ✅ test_completion_functions_exist
  ✅ test_cache_clear_functions_exist
  ✅ test_context_detection_function_exists
  ✅ test_external_database_functions_exist
  ✅ test_cache_commands_available
  ✅ test_intellisense_availability_check
  ✅ test_clear_all_caches_doesnt_error

Suite: 8/8 passed

================================================================================
Running: blink.cmp Integration
================================================================================

  ✅ test_blink_source_can_be_required
  ✅ test_blink_source_has_new_function
  ✅ test_blink_source_instance_creation
  ✅ test_get_trigger_characters_returns_table
  ✅ test_trigger_characters_include_dot
  ✅ test_enabled_returns_boolean
  ✅ test_source_transform_item_function
  ✅ test_column_info_formatting
  ✅ test_table_info_formatting

Suite: 9/9 passed

================================================================================
TEST SUMMARY
================================================================================

Total:  45
Passed: 45 ✅
Failed: 0 ❌

Success Rate: 100%

✅ Results saved to: ~/.local/share/nvim/dadbod_ui/test_results_20251021_193015.txt
```

---

## Test Suites

### 1. Database Connections (`connections.lua`)

Tests core DBUI functionality:
- Commands exist (DBUI, DBUIToggle, etc.)
- Configuration is set up correctly
- SSMS mode enabled
- Cache enabled

### 2. IntelliSense Cache (`intellisense_cache.lua`)

Tests Phase 1 & 2 cache system:
- Cache functions exist
- Commands available
- Clear/refresh works
- Context detection available

### 3. SQL Parser (`sql_parser.lua`)

Tests Phase 2 parser:
- External database detection
- Keyword filtering
- Function filtering
- Context detection

### 4. blink.cmp Integration (`blink_integration.lua`)

Tests Phase 4 native source:
- Source module loads
- Instance creation
- Required methods exist
- Trigger characters
- Enabled/disabled logic
- Item transformation
- Formatting functions

---

## Writing New Tests

### Test File Structure

```lua
-- lua/db_ui/tests/my_feature.lua
local M = {}
local test = require('db_ui.tests.init')

-- Optional: Setup before all tests
function M.setup()
  vim.g.db_ui_enable_intellisense = 1
end

-- Optional: Cleanup after all tests
function M.teardown()
  -- Clean up
end

-- Test functions (must start with 'test_')
function M.test_something_works()
  local value = get_something()

  test.assert_not_nil(value, "Value should exist")
  test.assert_equal(value, "expected", "Value should match")
end

function M.test_another_feature()
  local result = do_something()

  test.assert(result == true, "Should return true")
end

return M
```

### Available Assertions

```lua
-- Basic assertion
test.assert(condition, "message")

-- Equality
test.assert_equal(actual, expected, "message")

-- Not nil
test.assert_not_nil(value, "message")

-- Contains (for arrays)
test.assert_contains(table, value, "message")
```

### Adding to Test Suite

Edit `lua/db_ui/tests/init.lua` and add your suite:

```lua
local suites = {
  { name = "My Feature", module = "db_ui.tests.my_feature" },
  -- ... existing suites
}
```

---

## Test Results Location

Results are automatically saved to:
```
~/.local/share/nvim/dadbod_ui/test_results_<timestamp>.txt
```

On Windows:
```
C:\Users\<YourName>\AppData\Local\nvim-data\dadbod_ui\test_results_<timestamp>.txt
```

---

## Viewing Results

### In Neovim

Results appear in a split window automatically. You can:
- Scroll through results
- Close with `:q`
- Reopen saved files: `:edit ~/.local/share/nvim/dadbod_ui/test_results_*.txt`

### Find Latest Results

```vim
:!ls -t ~/.local/share/nvim/dadbod_ui/test_results_*.txt | head -1
```

Or navigate to the directory:
```vim
:edit ~/.local/share/nvim/dadbod_ui/
```

---

## Troubleshooting

### Tests Fail to Load

**Error**: `Could not load suite: <name>`

**Solution**: Check that the test file exists and has valid Lua syntax:
```vim
:lua require('db_ui.tests.my_feature')
```

### Assertion Failures

**Error**: `Assertion failed: <message>`

**Debug**: Add print statements in your test:
```lua
function M.test_something()
  local value = get_value()
  print("DEBUG: value =", vim.inspect(value))
  test.assert_equal(value, expected)
end
```

### Commands Not Found

**Error**: `E492: Not an editor command`

**Solution**: Ensure vim-dadbod-ui is loaded:
```vim
:echo exists('*db_ui#open')  " Should return 1
```

If not, reload your config:
```vim
:source $MYVIMRC
```

---

## Advantages Over vim-themis

| Feature | vim-themis | Native Neovim Tests |
|---------|------------|-------------------|
| **Lua Support** | ❌ (Vim only) | ✅ Native |
| **blink.cmp** | ❌ Can't test | ✅ Full access |
| **Buffer Ops** | ⚠️ Limited | ✅ Full API |
| **Live Environment** | ❌ Isolated | ✅ Real Neovim |
| **Windows Paths** | ⚠️ Issues | ✅ Works |
| **Setup** | Complex | ✅ Simple |
| **Output** | Terminal only | ✅ Buffer + File |

---

## Future Enhancements

Potential additions:
- [ ] Performance benchmarks
- [ ] Integration with CI/CD
- [ ] Async test support
- [ ] Mock database connections
- [ ] Coverage reporting
- [ ] Test filtering by pattern
- [ ] Watch mode (rerun on file change)

---

## Examples

### Test Lua Function

```lua
function M.test_lua_function_works()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  test.assert_not_nil(instance)
  test.assert_equal(type(instance), "table")
end
```

### Test VimL Function

```lua
function M.test_viml_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#init_cache'),
    1,
    "Function should exist"
  )
end
```

### Test Buffer Manipulation

```lua
function M.test_buffer_operations()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"SELECT * FROM Users"})

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  test.assert_equal(#lines, 1)
  test.assert_equal(lines[1], "SELECT * FROM Users")

  vim.api.nvim_buf_delete(bufnr, {force = true})
end
```

---

## Summary

This native Neovim test framework provides:
- ✅ Real environment testing
- ✅ Lua + VimL support
- ✅ Simple commands
- ✅ Beautiful output
- ✅ Saved results
- ✅ Easy to extend

**Run your first test now**:
```vim
:DBUITestFullSuite
```

🎉 Happy testing!
