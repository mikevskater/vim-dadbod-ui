# IntelliSense Implementation Guide for SSNS

## Context

This document captures the IntelliSense (auto-completion) implementation work done on the `vim-dadbod-ui` VimScript plugin on the **IntelliSense branch**. Use this as a reference when implementing IntelliSense for **SSNS** (SQL Server NeoVim Studio), the Lua-based rewrite.

---

## What Was Implemented (VimScript Version)

### Core Features Completed

1. **SSMS-Style Hierarchical Completion**
   - Type `DatabaseName.` → shows schemas
   - Type `SchemaName.` → shows tables/views
   - Type `TableName.` → shows columns
   - Type `ProcedureName` → shows parameters

2. **Intelligent Context Detection**
   - Parses SQL to understand cursor position
   - Detects table aliases (e.g., `FROM Employees e` then `e.` shows columns)
   - Handles qualified names (`dbo.Employees.ColumnName`)
   - Supports external database references (`OtherDB.dbo.Table`)

3. **Cross-Schema Table Search** (Attempted)
   - User types unqualified: `Employees.`
   - System searches all schemas to find which contains `Employees`
   - Auto-populates schema for column lookup
   - **Status**: Partially working, had issues with cache population

4. **Unified Cache System**
   - Single cache shared between DBUI tree and IntelliSense
   - TTL-based invalidation (default: 300 seconds)
   - Lazy loading design
   - **Issue**: Cache not properly populated from DB queries

---

## Key Challenges Encountered (CRITICAL - Learn from These!)

### 1. **VimScript ↔ Lua Type Conversion Hell**

**Problem**: Conversion between VimScript and Lua breaks constantly

```vim
" VimScript returns string
'column_name|data_type'

" Lua expects table
{name = 'column_name', type = 'data_type'}
```

**Lesson for SSNS**: **Never cross language boundaries in hot paths!** Keep completion entirely in Lua.

---

### 2. **Database Name vs Connection Name Confusion**

**Critical Bug Found**: DBUI stores TWO names:
- `db.name` = Connection name (e.g., "SQLEXPRESS")
- `db.db_name` = Actual database from URL (e.g., "vim_dadbod_test")

Query functions expect `db.db_name`, but we were passing `db.name`!

**Result**: Queries ran against wrong database (master instead of vim_dadbod_test)

**Solution**: Always use actual database name from connection URL

---

### 3. **Trigger Character Context Loss**

**Problem**: When user types `.`, the cursor context doesn't include it!

```
User types: "Employees."
ctx.line:   "Employees"   ← Missing dot!
ctx.cursor: [1, 10]       ← After dot
```

**Solution**: Fetch actual line from buffer:
```lua
local actual_line = vim.api.nvim_buf_get_lines(
  bufnr,
  ctx.cursor[1] - 1,
  ctx.cursor[1],
  false
)[1]
```

---

### 4. **SQL Server Row Count Messages**

**Problem**: `(0 rows affected)` mixed with data

```sql
SELECT column_name FROM INFORMATION_SCHEMA.COLUMNS
-- Returns: "(0 rows affected)\nEmployeeID\nFirstName"
```

**Solution**: Prepend `SET NOCOUNT ON;` to SELECT queries

---

### 5. **Cache Population Timing**

**Core Issue**: Cache empty on first completion request
- DBUI tree populates lazily (when user expands)
- IntelliSense triggers before expansion
- Result: 0 tables found, completion fails

**Attempted Solutions**:
- Auto-fetch metadata on first request
- Fallback to direct query if cache empty
- **Both had issues** with database name confusion (issue #2)

**For SSNS**: Populate cache eagerly on connection, not lazily

---

## Architecture Lessons for Lua Rewrite

### ✅ DO in SSNS:

1. **Single Hierarchical Cache in Pure Lua**
   ```lua
   Cache = {
     servers = {
       ["SQLEXPRESS"] = {
         databases = {
           ["vim_dadbod_test"] = {
             schemas = {
               ["dbo"] = {
                 tables = {
                   Employees = {
                     columns = {...}
                   }
                 }
               }
             }
           }
         }
       }
     }
   }
   ```

2. **Eager Population**
   ```lua
   -- On connection, immediately fetch:
   - List of databases
   - List of schemas (for active DB)
   - List of tables/views (for each schema)
   -- Lazy load columns/indexes only when needed
   ```

3. **Type-Safe Structures**
   ```lua
   ---@class Table
   ---@field name string
   ---@field schema string
   ---@field columns Column[]?  -- Lazy loaded

   ---@class Column
   ---@field name string
   ---@field data_type string
   ---@field nullable boolean
   ```

4. **Async Everything**
   ```lua
   local uv = vim.loop
   -- All DB queries must be non-blocking
   ```

5. **Single Source of Truth**
   - UI reads from cache
   - Completion reads from cache
   - Queries write to cache
   - **Never duplicate data**

---

### ❌ DON'T in SSNS:

1. **Don't Mix String/Table Formats**
   - Always return structured data
   - Never `"dbo.Employees"` when you can `{schema="dbo", name="Employees"}`

2. **Don't Use vim.fn in Completion**
   - VimScript boundary = performance killer
   - Pure Lua only

3. **Don't Parse Results Multiple Times**
   - Parse once on fetch
   - Store canonical format
   - Format on read

4. **Don't Block UI**
   - Use `vim.schedule()` for cache updates
   - Database queries on separate thread

5. **Don't Trust Lazy Loading for Core Data**
   - Tables/schemas: fetch immediately
   - Columns/indexes: lazy is OK

---

## SQL Query Examples (Reference)

### SQL Server Tables with Schema
```sql
SET NOCOUNT ON;
SELECT table_schema, table_name
FROM INFORMATION_SCHEMA.TABLES
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('sys', 'INFORMATION_SCHEMA')
  AND table_name NOT LIKE 'spt_%'
```

### SQL Server Columns with Metadata
```sql
SET NOCOUNT ON;
SELECT
  c.column_name,
  c.data_type,
  c.character_maximum_length,
  c.is_nullable,
  CASE WHEN pk.column_name IS NOT NULL THEN 1 ELSE 0 END as is_pk
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
  ON tc.table_name = c.table_name
LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE pk
  ON pk.constraint_name = tc.constraint_name
  AND pk.column_name = c.column_name
  AND tc.constraint_type = 'PRIMARY KEY'
WHERE c.table_schema = ? AND c.table_name = ?
ORDER BY c.ordinal_position
```

---

## Prompt for Future Claude Code Session

Save this as your initial prompt when starting the SSNS Lua rewrite:

```markdown
# Project: SSNS (SQL Server NeoVim Studio) - Lua Rewrite

I'm rewriting vim-dadbod-ui as a pure Lua Neovim plugin called SSNS.

## Current State
- Main branch: Working SSMS-style VimScript plugin with server browsing
- IntelliSense branch: Attempted auto-completion (see INTELLISENSE_IMPLEMENTATION_GUIDE.md)

## Goal
Create a clean Lua architecture with:
1. Hierarchical cache (Server → Database → Schema → Object)
2. SSMS-style UI (objects grouped by type)
3. IntelliSense completion (blink.cmp integration)
4. Async query execution
5. No VimScript in hot paths

## Reference Files
- VimScript UI: `autoload/db_ui.vim` (tree structure, object population)
- VimScript Completion: `autoload/db_ui/completion.vim` (context detection)
- VimScript Queries: `autoload/db_ui/schemas.vim` (SQL queries per DB type)
- IntelliSense Guide: `INTELLISENSE_IMPLEMENTATION_GUIDE.md` (lessons learned)

## First Task
Design the cache structure in `lua/ssns/cache.lua` with:
- Hierarchical organization matching SSMS
- Methods for get/set/invalidate
- TTL-based expiration
- Lazy loading support

Read INTELLISENSE_IMPLEMENTATION_GUIDE.md for critical lessons on what NOT to do!
```

---

## Test Database Structure

Create this for testing:

```sql
-- Database: vim_dadbod_test
USE vim_dadbod_test;

-- dbo schema
CREATE TABLE dbo.Employees (
  EmployeeID INT PRIMARY KEY,
  FirstName NVARCHAR(50) NOT NULL,
  LastName NVARCHAR(50) NOT NULL,
  Email NVARCHAR(100),
  DepartmentID INT,
  HireDate DATE DEFAULT GETDATE()
);

CREATE TABLE dbo.Departments (
  DepartmentID INT PRIMARY KEY,
  DepartmentName NVARCHAR(100) NOT NULL
);

-- hr schema
CREATE SCHEMA hr;

CREATE TABLE hr.Benefits (
  BenefitID INT PRIMARY KEY,
  BenefitName NVARCHAR(100),
  EmployeeID INT
);

-- Views
CREATE VIEW dbo.EmployeeView AS
  SELECT EmployeeID, FirstName, LastName FROM dbo.Employees;

-- Procedures
CREATE PROCEDURE dbo.GetEmployee @EmployeeID INT AS
  SELECT * FROM dbo.Employees WHERE EmployeeID = @EmployeeID;
```

**Test Completion Cases**:
1. `E` → should show Employees
2. `Employees.` → should show EmployeeID, FirstName, etc.
3. `dbo.` → should show Employees, Departments, EmployeeView
4. `hr.` → should show Benefits
5. `FROM Employees e WHERE e.` → should resolve alias

---

## Success Criteria for SSNS IntelliSense

- [ ] Type `TableName.` → see columns in <100ms
- [ ] Cache persists across buffers
- [ ] Schema auto-detection works (no manual qualification)
- [ ] Alias resolution works
- [ ] Zero VimScript in completion path
- [ ] Handles 1000+ tables without lag
- [ ] Clear error messages
- [ ] 80%+ test coverage

---

## Files to Create in SSNS

```
ssns/
├── lua/
│   ├── ssns/
│   │   ├── init.lua              # Plugin entry point
│   │   ├── config.lua            # User configuration
│   │   ├── cache.lua             # Hierarchical cache
│   │   ├── connection.lua        # DB connection management
│   │   ├── ui/
│   │   │   ├── tree.lua          # Tree renderer
│   │   │   └── highlights.lua    # Syntax highlighting
│   │   ├── adapters/
│   │   │   ├── sqlserver.lua     # SQL Server queries
│   │   │   ├── postgres.lua      # PostgreSQL queries
│   │   │   └── mysql.lua         # MySQL queries
│   │   └── completion/
│   │       ├── context.lua       # SQL context detection
│   │       └── source.lua        # Blink.cmp source
│   └── blink/
│       └── cmp/
│           └── sources/
│               └── ssns.lua      # Blink integration
└── doc/
    └── ssns.txt                  # Help documentation
```

---

## Key Implementation Notes

### Cache Structure Example
```lua
-- lua/ssns/cache.lua
local M = {}

M.servers = {}

---@class ServerCache
---@field name string
---@field url string
---@field databases table<string, DatabaseCache>

---@class DatabaseCache
---@field name string
---@field schemas table<string, SchemaCache>
---@field loaded boolean
---@field last_updated number

---@class SchemaCache
---@field name string
---@field tables table<string, TableCache>
---@field views table<string, ViewCache>
---@field loaded boolean

---@class TableCache
---@field name string
---@field schema string
---@field columns Column[]?  -- Lazy loaded
---@field loaded boolean

---@class Column
---@field name string
---@field data_type string
---@field nullable boolean
---@field is_pk boolean
---@field is_fk boolean
```

### Blink.cmp Source Example
```lua
-- lua/blink/cmp/sources/ssns.lua
local cache = require('ssns.cache')
local context = require('ssns.completion.context')

local source = {}

function source:get_completions(ctx, callback)
  local db_key = vim.b[ctx.bufnr].ssns_db_key
  if not db_key then
    return callback({ items = {} })
  end

  -- Pure Lua, no vim.fn!
  local sql_context = context.detect(ctx.cursor, ctx.line)

  if sql_context.type == 'column' then
    local columns = cache.get_columns(
      db_key,
      sql_context.schema,
      sql_context.table
    )

    local items = vim.tbl_map(function(col)
      return {
        label = col.name,
        kind = vim.lsp.protocol.CompletionItemKind.Field,
        detail = col.data_type,
        documentation = string.format(
          "Type: %s\nNullable: %s\nPK: %s",
          col.data_type,
          col.nullable and "Yes" or "No",
          col.is_pk and "Yes" or "No"
        )
      }
    end, columns)

    callback({ items = items })
  end
end

return source
```

---

## Migration Path

1. **Week 1**: Cache + Query Layer
   - Implement hierarchical cache
   - SQL Server adapter with async queries
   - Unit tests

2. **Week 2**: Completion
   - Context detection (TreeSitter or regex)
   - Blink.cmp source
   - Integration tests

3. **Week 3**: UI
   - Tree renderer reading from cache
   - SSMS-style grouping
   - Keymaps

4. **Week 4**: Polish
   - Error handling
   - Documentation
   - Performance optimization
   - Migration guide

---

Good luck with the rewrite! The Lua version will be so much cleaner. 🚀
