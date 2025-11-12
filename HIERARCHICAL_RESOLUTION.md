# Hierarchical Context Resolution & Live Loading

## Overview

Implemented **SSMS-style hierarchical context resolution** with **lazy loading** for external databases. The system now intelligently determines what each identifier refers to by checking the cache in order: Database → Schema → Table.

---

## How It Works

### Hierarchical Resolution Logic

When you type `word1.word2`:

1. **Check if word1 is a DATABASE**
   - If YES → Suggest schemas from that database
   - If typing `word2` → Filter schemas matching `word2`

2. **Check if word1 is a SCHEMA**
   - If YES and `word2` is empty (just dot) → Suggest all tables from that schema
   - If YES and typing `word2` → Filter tables matching `word2`
   - If YES and `word2` is a known TABLE → Show columns

3. **Check if word1 is a TABLE**
   - If YES → Show columns from that table

4. **Fallback**: Assume schema.table pattern

### Live Loading (Lazy Loading)

When you reference an external database:

```sql
SELECT * FROM OtherDB.dbo.Employees
```

**What happens**:
1. You type `OtherDB.` → System detects "OtherDB" is a database
2. **Auto-triggers fetch**: `ensure_external_db_cached('OtherDB')`
3. **Shows notification**: "Loading OtherDB metadata..."
4. **Fetches in background**: Tables, views, procedures, functions from OtherDB
5. **Caches results**: Now available for completion
6. You continue typing `dbo.` → Shows tables from OtherDB.dbo schema
7. You type `Emp` → Filters to tables starting with "Emp"

**No pre-loading required!** Data loads as you type.

---

## Examples

### Example 1: Same Database, Different Schema

**Scenario**: Connected to `AdventureWorks`, typing in different schema

```sql
SELECT * FROM Sales.
```

**Resolution**:
1. Check: Is "Sales" a database? NO
2. Check: Is "Sales" a schema? YES
3. **Result**: Show all tables from Sales schema

```sql
SELECT * FROM Sales.C
```

**Resolution**:
1. Check: Is "Sales" a schema? YES
2. Typing "C" → Filter tables
3. **Result**: Show tables from Sales schema starting with "C" (Customer, Currency, etc.)

---

### Example 2: External Database Reference

**Scenario**: Connected to `DB1`, referencing `DB2`

```sql
SELECT * FROM DB2.dbo.Users
```

**Typing `DB2.`**:
1. Check: Is "DB2" a database? YES
2. **Trigger**: `ensure_external_db_cached('DB2')`
3. **Notification**: "Loading DB2 metadata..."
4. **Fetch**: All schemas, tables, views, procedures, functions from DB2
5. **Result**: Show schemas from DB2

**Typing `DB2.dbo.`**:
1. Cache now has DB2 data
2. Check: "DB2" is database, "dbo" is schema
3. **Result**: Show all tables from DB2.dbo

**Typing `DB2.dbo.U`**:
1. **Result**: Filter to tables starting with "U" (Users, UserRoles, etc.)

---

### Example 3: Column Completion

**Scenario**: Getting columns from qualified table

```sql
SELECT * FROM dbo.Employees.
```

**Resolution**:
1. Check: Is "dbo" a database? NO
2. Check: Is "dbo" a schema? YES
3. Check: Is "Employees" a table in dbo schema? YES
4. **Result**: Show columns from dbo.Employees

```sql
SELECT * FROM OtherDB.dbo.Employees.
```

**Resolution**:
1. Check: Is "OtherDB" a database? YES
2. **Trigger lazy load**: Fetch OtherDB metadata
3. Check: Is "dbo" a schema in OtherDB? YES
4. Check: Is "Employees" a table? YES
5. **Result**: Show columns from OtherDB.dbo.Employees

---

## Implementation Details

### Helper Functions

#### `s:is_database(db_key_name, identifier)`
Checks if identifier matches a known database name in cache.

```vim
if s:is_database(db_key, 'AdventureWorks')
  " It's a database!
endif
```

#### `s:is_schema(db_key_name, identifier)`
Checks if identifier matches a known schema name.

```vim
if s:is_schema(db_key, 'dbo')
  " It's a schema!
endif
```

#### `s:is_table(db_key_name, identifier, [schema])`
Checks if identifier matches a known table or view, optionally filtered by schema.

```vim
if s:is_table(db_key, 'Employees', 'dbo')
  " It's a table in dbo schema!
endif
```

#### `s:resolve_hierarchical_context(db_key, parts, has_trailing)`
Main resolution function - checks each identifier hierarchically.

**Parameters**:
- `db_key`: Current database connection
- `parts`: Array of identifiers (e.g., `['dbo', 'Employees']`)
- `has_trailing`: True if there's text after last dot (not just whitespace)

**Returns**: Context dictionary with `type`, `database`, `schema`, `table`

### Live Loading Functions

#### `db_ui#completion#ensure_external_db_cached(server_key, db_name)`
Public API - ensures external database is cached.

**Behavior**:
- Checks if already cached and valid
- If not → triggers async fetch
- Shows "Loading..." notification
- Returns immediately (non-blocking)

#### `db_ui#completion#fetch_external_database(server_key, db_name)`
Internal function - performs actual metadata fetch.

**Fetches**:
- Tables
- Views
- Procedures
- Functions
- Schemas (from first query results)

**Caches** in: `s:completion_cache[server_key].external_databases[db_name]`

---

## Configuration

### Enable/Disable External Database Fetching

```vim
" Enable (default)
let g:db_ui_intellisense_fetch_external_db = 1

" Disable
let g:db_ui_intellisense_fetch_external_db = 0
```

### Show/Hide Loading Notifications

```vim
" Show notifications (default)
let g:db_ui_show_loading_indicator = 1

" Hide notifications
let g:db_ui_show_loading_indicator = 0
```

### Cache TTL

```vim
" Default: 300 seconds (5 minutes)
let g:db_ui_cache_ttl = 300

" Longer cache: 30 minutes
let g:db_ui_cache_ttl = 1800
```

---

## Performance Considerations

### When Does Live Loading Happen?

**Trigger**: When you type a qualified name and the first part is detected as a database

**Examples**:
- `OtherDB.` → Triggers fetch for OtherDB
- `OtherDB.dbo.` → Fetch already triggered on previous step
- `OtherDB.dbo.E` → Using cached data

### Caching Strategy

**First Reference**: Fetch triggered, slight delay while loading

**Subsequent References**: Instant (cached)

**Cache Expiry**: After TTL (default 5 min), re-fetches on next use

### Network Impact

**Minimal**: Only fetches databases actually referenced in queries

**Example**:
- Server has 50 databases
- You only type `DB1.dbo.` and `DB2.dbo.`
- **Only fetches**: DB1 and DB2 (not all 50!)

---

## Comparison with DBUI Tree Expansion

### DBUI Tree (Manual Expansion)

```
▾  SQLSERVER
   ▸  Databases
     ▸  DB1
       ▸  TABLES    ← Click to load
       ▸  VIEWS     ← Click to load
     ▸  DB2
       ▸  TABLES    ← Click to load
```

**Loading**: Manual - user must click to expand each level

**When**: Explicit user action

### IntelliSense (Auto Lazy Loading)

```sql
SELECT * FROM DB2.dbo.Employees
              ^^^^ ← Typing this triggers auto-load
```

**Loading**: Automatic - triggers as you type

**When**: Implicit - when you reference the database in code

---

## Debug & Troubleshooting

### Enable Debug Mode

```vim
:call db_ui#completion#toggle_debug()
```

### Check Messages

```vim
:messages
```

**Look for**:
```
[db_ui_completion] Hierarchical: DB2 is database, suggesting schemas
[db_ui_completion] Live-loading external DB: DB2
[db_ui_completion] External DB already cached: DB2
[db_ui_completion] Hierarchical: dbo is schema in DB2, suggesting tables
```

### Check Cache Status

```vim
:DBUICompletionStatus
```

**Example Output**:
```
Database: MyServer_localhost
  External DBs: 2
    - OtherDB1: 15 tables, 5 views
    - OtherDB2: 8 tables, 2 views
```

---

## Advanced Scenarios

### Cross-Database Joins

```sql
SELECT
  u.Name,
  o.OrderDate
FROM DB1.dbo.Users u
JOIN DB2.dbo.Orders o ON u.Id = o.UserId
```

**Resolution**:
1. Typing `DB1.dbo.` → Loads DB1 metadata
2. Typing `DB2.dbo.` → Loads DB2 metadata
3. Both cached for remainder of session

### Synonym Resolution (Future Enhancement)

```sql
SELECT * FROM MySynonym.
```

If synonyms point to external databases, the system could:
1. Detect "MySynonym" is a synonym
2. Resolve actual target: `OtherDB.dbo.RealTable`
3. Trigger load for OtherDB
4. Show columns from the real table

*Not yet implemented - requires synonym metadata*

---

## Benefits Over Static Loading

### Memory Efficient
- Only loads what you use
- Server with 100 databases? Only loads the 2-3 you reference

### Network Efficient
- No upfront bulk queries
- Loads on-demand as needed

### Fast Startup
- No delay connecting to server
- Background loading as you type

### Always Fresh
- TTL-based expiration
- Auto-refreshes stale data

---

## Files Modified

1. **`autoload/db_ui/completion.vim`**
   - Lines 934-1013: Helper functions (`is_database`, `is_schema`, `is_table`)
   - Lines 1015-1128: Hierarchical resolution function
   - Lines 421-450: Live loading wrapper (`ensure_external_db_cached`)
   - Lines 697-804: Updated context detection to use hierarchical resolution
   - Lines 743-746, 714-717: Trigger lazy loading when external DB detected

2. **`autoload/db_ui/schemas.vim`**
   - Lines 638-671: Created `query_tables()` function with database field
   - System tables filtered out

---

## Summary

**Before**: Static pattern matching - "dbo.E" always means "schema.table"

**After**: Intelligent resolution - checks cache to determine what "dbo" actually refers to (DB? Schema? Table?)

**Result**: True SSMS-style IntelliSense with lazy loading! 🚀
