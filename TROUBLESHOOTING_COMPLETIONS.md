# Troubleshooting IntelliSense Completions

## Step-by-Step Debugging Guide

Follow these steps IN ORDER to identify where the completion pipeline is failing.

---

## Step 1: Verify Database Connection

1. Open Neovim
2. Run `:DBUI` to open the database drawer
3. Navigate to your SQL Server connection and press `<CR>` to expand it
4. You should see tables, views, procedures listed in the drawer

**If you DON'T see objects in the drawer:**
- Check your connection string in `g:dbs` or saved connections
- Try running a manual query: `:DB SELECT 1` from a query buffer
- The connection might be failing

---

## Step 2: Open a Query Buffer and Check Buffer Variables

1. From DBUI, press `o` on your database to open a new query buffer
2. In the query buffer, run these commands:

```vim
:echo b:dbui_db_key_name
:echo b:db
```

**Expected Output:**
```
YourDB_localhost_1433  (or similar)
... (connection info)
```

**If `b:dbui_db_key_name` is empty:**
- The buffer wasn't set up correctly by DBUI
- Try closing and reopening the query buffer from DBUI

---

## Step 3: Run the Direct Test Script

From your query buffer, run:

```vim
:source C:\Users\ShiFt\AppData\Local\nvim-data\lazy\vim-dadbod-ui\test_direct.vim
```

**This will show you:**
1. Database key name
2. Table count from cache
3. Sample tables with their structure
4. Context detection for "dbo.E"
5. Whether blink.cmp source is loaded

**Look for:**
- ✅ "Tables count: 15" (or any non-zero number)
- ✅ Tables have `schema` property
- ✅ Context type is `table` for "dbo.E"
- ✅ Context schema is `dbo`

**If tables count is 0:**
- Cache isn't populated → Go to Step 4

**If tables don't have `schema` property:**
- Wrong table format → Go to Step 5

**If context type is NOT `table`:**
- Context detection broken → Go to Step 6

---

## Step 4: Check Cache Status and Refresh

Run these commands:

```vim
:DBUICompletionStatus
```

**Expected Output:**
```
Database: YourDB_localhost_1433
  Tables: 15
  Views: 5
  Procedures: 12
  Functions: 8
  Schemas: 2
  Age: 10s / 300s TTL
  Loading: No
```

**If showing "Loading: Yes" forever:**
- Cache initialization is stuck
- Check `:messages` for errors
- Enable debug: `:call db_ui#completion#toggle_debug()`
- Run `:DBUIRefreshCompletion` to retry

**If all counts are 0:**
- Cache populated but empty
- Go to Step 5 (check scheme_info)

---

## Step 5: Enable Debug Mode and Check Metadata Fetch

Enable debug logging:

```vim
:call db_ui#completion#toggle_debug()
:DBUIRefreshCompletion
:messages
```

**Look for these debug messages:**

```
[db_ui_completion] init_cache called for: YourDB_localhost_1433
[db_ui_completion] Fetching metadata for: YourDB_localhost_1433
[db_ui_completion] Fetched and cached 15 tables
[db_ui_completion] Fetched and cached 5 views
[db_ui_completion] Fetched and cached 12 procedures
[db_ui_completion] Fetched and cached 8 functions
[db_ui_completion] Metadata fetch complete
```

**If you see errors about "scheme_info":**
```
[db_ui_completion] No scheme info available for: sqlserver
```
- The `db_ui#schemas#get()` function isn't returning scheme info
- Check if `autoload/db_ui/schemas.vim` has the scheme definition
- Run: `:echo db_ui#schemas#get('sqlserver')`

**If you see errors about function parameters:**
```
Not enough arguments for db_ui#schemas#query_tables
```
- The scheme parameter fix didn't apply correctly
- Re-source the completion file: `:source autoload/db_ui/completion.vim`

---

## Step 6: Test Context Detection Manually

Run these tests in your query buffer:

```vim
:source test_direct.vim
```

Look at the "Testing context for" section. It tests "dbo.E".

**Expected:**
```
Testing context for: 'SELECT * FROM dbo.E'
Context result:
  type: table
  schema: dbo
  table: N/A
  database: N/A
```

**If type is NOT 'table':**
- Pattern matching isn't working
- Check the VimScript pattern fix was applied
- Try: `:echo 'SELECT * FROM dbo.E' =~# '\<\w\+\.\w\+$'`
  Should return: `1` (true)

**If schema is NOT 'dbo':**
- Pattern extraction broken
- Try: `:echo matchstr('SELECT * FROM dbo.E', '\<\w\+\.\w\+$')`
  Should return: `dbo.E`

---

## Step 7: Check blink.cmp Configuration

Check if blink.cmp is loading the dadbod source:

```vim
:lua vim.print(require('blink.cmp.config').sources.providers)
```

**Look for:**
```lua
dadbod = {
  name = 'Dadbod',
  module = 'blink.cmp.sources.dadbod',
  -- ...
}
```

**If dadbod source is missing:**
- Check your blink.cmp config
- Add the source manually (see blink.cmp docs)

**Check if source is enabled:**

```vim
:lua vim.print(require('blink.cmp.sources.dadbod').enabled())
```

Should return: `true`

**If false:**
- Filetype not supported
- IntelliSense disabled: check `g:db_ui_enable_intellisense`
- Run: `:echo &filetype` (should be `sql`)

---

## Step 8: Test blink.cmp Manually

With debug still enabled, try typing:

```sql
SELECT * FROM dbo.E
```

**Check :messages for:**
```
[db_ui_completion] get_cursor_context: before_cursor="SELECT * FROM dbo.E"
[db_ui_completion] Table completion for schema.partial: dbo.E
```

**If you see these messages:**
- Context detection is working ✅
- Problem is in Lua source

**Now check Lua side:**

Type the text above, then immediately run (while dropdown is visible/invisible):

```vim
:lua vim.print(vim.fn['db_ui#completion#get_completions'](vim.b.dbui_db_key_name, 'tables'))
```

**Should see array of tables with schema property:**
```lua
{
  { name = "Employees", schema = "dbo", type = "table" },
  { name = "Errors", schema = "dbo", type = "table" },
  { name = "Users", schema = "hr", type = "table" },
}
```

**If tables don't have `schema` property:**
- `db_ui#schemas#query_tables()` not returning correct format
- Need to check `autoload/db_ui/schemas.vim`

---

## Step 9: Check Lua Source Filtering

Test if schema filtering works in Lua:

```vim
:lua << EOF
local db_key = vim.b.dbui_db_key_name
local tables = vim.fn['db_ui#completion#get_completions'](db_key, 'tables')
print("Total tables: " .. #tables)

-- Filter for dbo schema
local dbo_tables = vim.tbl_filter(function(obj)
  return obj.schema and obj.schema:lower() == 'dbo'
end, tables)
print("DBO tables: " .. #dbo_tables)

-- Print first 3
for i = 1, math.min(3, #dbo_tables) do
  print("  " .. dbo_tables[i].name)
end
EOF
```

**Expected:**
```
Total tables: 20
DBO tables: 15
  Employees
  Errors
  Users
```

**If DBO tables: 0:**
- No tables have `schema = 'dbo'`
- Schema names might be uppercase: `DBO` vs `dbo`
- Check actual schema names: `:lua vim.print(tables[1])`

---

## Step 10: Force Refresh and Restart

Sometimes cached state gets corrupted. Try:

```vim
:DBUIRefreshCompletionAll
:lua package.loaded['blink.cmp.sources.dadbod'] = nil
:lua require('blink.cmp.sources.dadbod')
```

Then reopen the query buffer from DBUI.

---

## Common Issues and Fixes

### Issue 1: "Function doesn't exist" errors

**Symptom**: `E117: Unknown function: db_ui#completion#get_completions`

**Fix**: The completion file isn't loaded
```vim
:source C:\Users\ShiFt\AppData\Local\nvim-data\lazy\vim-dadbod-ui\autoload\db_ui\completion.vim
```

### Issue 2: Tables have wrong structure (strings instead of objects)

**Symptom**: Tables are `["Users", "Employees"]` instead of `[{name: "Users", schema: "dbo"}]`

**Fix**: Using DBUI cache instead of query functions
- Check line 170-175 in `completion.vim`
- Should call `db_ui#schemas#query_tables(db_info, scheme_info)`
- NOT `get(db_info, 'tables', [])`

### Issue 3: scheme_info is empty

**Symptom**: Debug shows "No scheme info available"

**Fix**: Check scheme definition exists
```vim
:echo db_ui#schemas#get('sqlserver')
```

Should return a dictionary with query functions.

If empty:
- Check `autoload/db_ui/schemas.vim` has your database type
- For SQL Server, should be `sqlserver` or `sqlsrv`

### Issue 4: Context always returns 'all_objects'

**Symptom**: No matter what you type, context.type is 'all_objects'

**Fix**: Pattern matching not working
- Check `autoload/db_ui/completion.vim` lines 737-783
- Patterns should match `\<\w\+\.\w\+$` for "dbo.E"
- Test pattern: `:echo 'dbo.E' =~# '\<\w\+\.\w\+$'` → should be 1

### Issue 5: blink.cmp dropdown is empty even with data

**Symptom**: Cache has tables, context is correct, but no dropdown

**Fix**: Check blink.cmp source is being called
- Add debug prints to `lua/blink/cmp/sources/dadbod.lua:get_completions()`
- Check if `callback()` is being called with items
- Verify `items` array is not empty

---

## Expected Full Pipeline (Working)

When you type `SELECT * FROM dbo.E`, this should happen:

1. **Buffer setup** (autoload/db_ui/query.vim:197):
   - Calls `db_ui#completion#init_cache(db_key_name)`

2. **Cache initialization** (autoload/db_ui/completion.vim:146-217):
   - Gets `scheme_info` for 'sqlserver'
   - Calls `db_ui#schemas#query_tables(db_info, scheme_info)`
   - Caches tables with structure: `{name, schema, type}`

3. **Typing triggers completion**:
   - blink.cmp calls `source:get_completions(ctx, callback)`

4. **Context detection** (autoload/db_ui/completion.vim:625-656):
   - Parses "dbo.E"
   - Matches pattern `\<\w\+\.\w\+$`
   - Returns `{type: 'table', schema: 'dbo'}`

5. **Get items** (lua/blink/cmp/sources/dadbod.lua:216-255):
   - Calls `get_table_items(db_key, context)`
   - Gets all tables from cache
   - Filters by `schema == 'dbo'`
   - Returns filtered list

6. **Transform items** (lua/blink/cmp/sources/dadbod.lua:433-472):
   - Converts to LSP format
   - Sets `filterText = table.name`

7. **blink.cmp filters**:
   - Fuzzy matches "E" against filterText
   - Shows "Employees", "Errors"

---

## Report Back

After running through these steps, please report:

1. **Which step failed?** (Step number)
2. **What was the output?** (Copy exact error messages)
3. **What does `:messages` show?** (After enabling debug)
4. **What does the test script show?** (Output of test_direct.vim)

This will help pinpoint the exact issue!
