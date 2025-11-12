# Testing Phase 1: Quick Start Guide

## Prerequisites

1. Neovim with vim-dadbod-ui installed
2. SQL Server database connection configured
3. blink.cmp configured with dadbod source

## Quick Test (5 minutes)

### Step 1: Clear Cache
```vim
:DBUIClearCache
```

### Step 2: Restart Neovim
This ensures all new code is loaded.

### Step 3: Open DBUI and Connect
```vim
:DBUI
```
Navigate to your database and expand it (this populates the cache).

### Step 4: Open a SQL Buffer
Press `o` on the database to create a new query buffer.

### Step 5: Test Unqualified Table Completion
Type in the buffer:
```sql
SELECT * FROM Employees.
```

**Expected Result**: You should see column completions appear (EmployeeID, FirstName, etc.)

### Step 6: Check Debug Messages
```vim
:messages
```

**Look for these messages**:
```
[DBUI-VIM] find_table_schema: Found Employees in schema dbo (completion cache)
[DBUI-VIM] Hierarchical: Employees is table in schema dbo, showing columns
[DBUI]   context.schema: dbo
[DBUI]   resolved table_name: dbo.Employees
```

## Automated Test

Run the test script:
```vim
:source test_phase1.vim
:call TestPhase1()
```

## Debug Commands

If something doesn't work, try these:

### 1. Check Cache Contents
```vim
:call db_ui#completion#show_cache_debug('your_db_key_name')
```

### 2. Check Connection
```vim
:echo exists('*db_ui#get_conn_info')
:echo b:dbui_db_key_name
```

### 3. Check if Completion Module Loaded
```vim
:echo exists('*db_ui#completion#get_cursor_context')
```

### 4. Manual Context Test
```vim
:let ctx = db_ui#completion#get_cursor_context(bufnr('%'), 'SELECT * FROM Employees.', 27)
:echo ctx
```

Expected output:
```
{'type': 'column', 'table': 'Employees', 'schema': 'dbo', ...}
```

## Troubleshooting

### No Columns Appear

**Cause**: Cache might be empty
**Fix**: 
1. Expand tables in DBUI tree first
2. Or wait for cache to populate (happens on first completion trigger)
3. Run `:DBUIClearCache` and try again

### Wrong Columns Appear

**Cause**: Schema detection failed
**Fix**: Check `:messages` to see which schema was detected

### No Debug Messages

**Cause**: Debug mode might be disabled
**Fix**: Check `g:db_ui_debug` setting

### Completion Menu Doesn't Show

**Cause**: blink.cmp might not be triggering
**Fix**: 
1. Check if dadbod source is enabled: `:lua print(vim.inspect(require('blink.cmp').config.sources.providers.dadbod))`
2. Manually trigger: `<C-Space>`

## Success Criteria

✅ Typing `Employees.` shows columns  
✅ Debug messages show "Found Employees in schema dbo"  
✅ Works without manually typing schema name  
✅ Works for tables in different schemas  

## Report Issues

If Phase 1 doesn't work:
1. Share the output of `:messages`
2. Share the output of `:call TestPhase1()`
3. Share the output of `:call db_ui#completion#show_cache_debug('your_db_key')`
