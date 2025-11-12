# CLAUDE.md

This file provides guidance to Claude Code when working on the SSNS project.

## Project Overview

**SSNS** (SQL Server NeoVim Studio) is a pure Lua Neovim plugin for database management with SSMS-style UI and IntelliSense completion. It's a complete rewrite of vim-dadbod-ui.

## Core Architecture

### Multi-Database Class Hierarchy

SSNS uses **universal classes** that work for ALL database types (SQL Server, PostgreSQL, MySQL, SQLite, BigQuery) with **database-specific adapters** for queries.

```
Universal Classes (99%)          Adapters (1%)
    │                                │
Server ─┬─ Database ─┬─ Schema      SqlServerAdapter
        │            ├─ Table        PostgresAdapter
        │            ├─ View         MySqlAdapter
        │            └─ ...          SqliteAdapter
```

**Key Principle**: Write once, support many databases.

### Class Structure

```lua
BaseDbObject (abstract)
    ├─ ServerClass       -- Connection, db_type, adapter
    ├─ DbClass           -- Database name, schemas
    ├─ SchemaClass       -- Tables, views, procedures, functions
    ├─ TableClass        -- Columns, indexes, constraints
    ├─ ViewClass
    ├─ ProcedureClass
    ├─ FunctionClass
    ├─ SynonymClass      -- SQL Server specific
    ├─ SequenceClass     -- PostgreSQL, Oracle
    ├─ ColumnClass
    ├─ IndexClass
    ├─ ConstraintClass
    └─ ParameterClass
```

Every class inherits from `BaseDbObject` with:
- `parent` - Parent in hierarchy
- `children` - Child objects
- `is_loaded` - Lazy loading flag
- `ui_state` - Display properties (separate from data)
- `get_full_path()` - Hierarchical path
- `get_adapter()` - Database-specific adapter

### Adapter Pattern

```lua
BaseAdapter (interface)
    ├─ SqlServerAdapter (priority 1)
    ├─ PostgresAdapter
    ├─ MySqlAdapter
    ├─ SqliteAdapter
    └─ BigQueryAdapter

Features per adapter:
    - schemas (boolean)
    - synonyms (boolean)
    - procedures (boolean)
    - sequences (boolean)
```

## Development Priority

**UI First, IntelliSense Later!**

### Current Phase: Phase 1-7 (UI Implementation)

**Phase 1**: Class hierarchy
**Phase 2**: Adapter system (SQL Server first)
**Phase 3**: Connection management
**Phase 4**: UI tree renderer
**Phase 5**: User interactions
**Phase 6**: Query buffers
**Phase 7**: Configuration & polish

### Later: Phase 8 (IntelliSense)

Only start after UI is fully working. See `INTELLISENSE_IMPLEMENTATION_GUIDE.md` for critical lessons learned from previous attempt.

## Essential Documents

**Read these in order when starting work:**

1. **SSNS_ARCHITECTURE.md** - Complete class structure with type annotations
2. **SSNS_MULTI_DATABASE.md** - Adapter pattern and multi-database support
3. **SSNS_ROADMAP.md** - Development phases and tasks
4. **SSNS_QUICKSTART.md** - How to implement first classes
5. **INTELLISENSE_IMPLEMENTATION_GUIDE.md** - What NOT to do (for Phase 8)

## File Organization

```
lua/ssns/
├── init.lua                    # Plugin entry point
├── config.lua                  # User configuration
├── cache.lua                   # Global cache (servers array)
├── factory.lua                 # Object creation factory
├── connection.lua              # DB connection management
├── classes/                    # Universal (ALL databases)
│   ├── base.lua                # BaseDbObject
│   ├── server.lua
│   ├── database.lua
│   ├── schema.lua
│   ├── table.lua
│   ├── column.lua
│   ├── view.lua
│   ├── procedure.lua
│   ├── function.lua
│   ├── synonym.lua
│   ├── sequence.lua
│   ├── index.lua
│   ├── constraint.lua
│   └── parameter.lua
├── adapters/                   # Database-specific
│   ├── base.lua                # BaseAdapter interface
│   ├── factory.lua             # Create from connection string
│   ├── sqlserver.lua           # SQL Server (priority 1)
│   ├── postgres.lua
│   ├── mysql.lua
│   └── sqlite.lua
└── ui/
    ├── tree.lua                # Tree renderer
    ├── buffer.lua              # Buffer management
    ├── query.lua               # Query execution
    └── highlights.lua          # Syntax highlighting
```

## Code Conventions

### LuaLS Type Annotations

**ALWAYS use type annotations:**

```lua
---@class TableClass : BaseDbObject
---@field table_name string
---@field column_list ColumnClass[]?
---@field parent SchemaClass
local TableClass = {}

---Get columns (lazy load if needed)
---@return ColumnClass[]
function TableClass:get_columns()
  -- implementation
end
```

### Parent/Child Relationships

**Always maintain bidirectional references:**

```lua
function BaseDbObject:add_child(child)
  child.parent = self
  table.insert(self.children, child)
end
```

### Lazy Loading Pattern

```lua
function TableClass:get_columns()
  if not self.columns_loaded then
    local adapter = self:get_adapter()
    local query = adapter:get_columns_query(...)
    local results = adapter:execute(query)
    self.column_list = adapter:parse_columns(results)
    self.columns_loaded = true
  end
  return self.column_list
end
```

### Adapter Usage

```lua
-- In universal class
function SchemaClass:load_tables()
  local adapter = self:get_adapter()

  -- Adapter provides database-specific query
  local query = adapter:get_tables_query(self.parent.db_name, self.schema_name)

  -- Adapter executes and parses
  local results = adapter:execute(self:get_server().connection, query)

  self.table_list = {}
  for _, row in ipairs(results) do
    local table = adapter:create_table(self, row)
    table.insert(self.table_list, table)
  end

  return self.table_list
end
```

## Critical Design Decisions

### ✅ DO:

1. **Separate UI state from data**
   ```lua
   BaseDbObject:
     - name (data)
     - ui_state.expanded (display)
   ```

2. **Use factory pattern for object creation**
   ```lua
   local server = Factory.create_server(connection_string)
   ```

3. **Feature flags in adapters**
   ```lua
   if adapter.features.synonyms then
     schema:load_synonyms()
   end
   ```

4. **Pure Lua, no VimScript in hot paths**

5. **Lazy load columns/indexes, eager load tables/schemas**

6. **Type annotations everywhere**

### ❌ DON'T:

1. **Don't duplicate data** - One tree for UI AND IntelliSense

2. **Don't mix string/table formats**
   ```lua
   -- BAD
   tables = {"[dbo].[Employees]", "[hr].[Benefits]"}

   -- GOOD
   tables = {
     {schema="dbo", name="Employees"},
     {schema="hr", name="Benefits"}
   }
   ```

3. **Don't forget parent references** - Set in constructor

4. **Don't eager load everything** - Lazy load when expensive

5. **Don't put business logic in adapters** - Only queries/parsing

## Common Tasks

### Adding a New Class

1. Create `lua/ssns/classes/newclass.lua`
2. Inherit from `BaseDbObject`
3. Add LuaLS annotations
4. Implement constructor
5. Add to factory
6. Write tests

### Adding a New Database

1. Create `lua/ssns/adapters/newdb.lua`
2. Inherit from `BaseAdapter`
3. Set `features` flags
4. Implement all query methods
5. Implement parsing methods
6. Register in `adapters/factory.lua`
7. Test with real database

### Debugging

```lua
-- Print object hierarchy
function debug_tree(obj, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  print(prefix .. obj.name)
  for child in obj:get_children() do
    debug_tree(child, indent + 1)
  end
end

-- Check if fully loaded
local function is_fully_loaded(obj)
  if not obj.is_loaded then
    return false, obj:get_full_path() .. " not loaded"
  end
  for child in obj:get_children() do
    local loaded, reason = is_fully_loaded(child)
    if not loaded then return false, reason end
  end
  return true
end
```

## Reference Implementation

**VimScript version**: vim-dadbod-ui (main branch)
- `autoload/db_ui.vim` - Tree structure reference
- `autoload/db_ui/schemas.vim` - SQL query examples
- `autoload/db_ui/drawer.vim` - UI rendering patterns

**Convert to Lua, don't port directly!**

## Testing Strategy

### Unit Tests (Phase 1)

```lua
-- tests/base_spec.lua
local BaseDbObject = require('ssns.classes.base')

describe('BaseDbObject', function()
  it('should create instance', function()
    local obj = BaseDbObject.new({ name = "test" })
    assert.equals("test", obj.name)
  end)

  it('should handle parent/child', function()
    local parent = BaseDbObject.new({ name = "parent" })
    local child = BaseDbObject.new({ name = "child" })
    parent:add_child(child)
    assert.equals(parent, child.parent)
  end)
end)
```

### Integration Tests (Phase 4)

Test with real test database:
- Create test DB with known structure
- Test expand/collapse
- Test lazy loading
- Test query execution

## Performance Considerations

1. **Lazy load columns/indexes** - Don't fetch until expanded
2. **TTL caching** - Default 300 seconds
3. **Async queries** - Use vim.loop for non-blocking
4. **Pagination** - For 1000+ objects

## Success Criteria

### Phase 1-7 Complete (UI):
- [ ] Tree displays server → database → schema → table hierarchy
- [ ] Expand/collapse works smoothly
- [ ] Can view table columns/indexes
- [ ] Can execute SELECT on table
- [ ] Query buffers work
- [ ] No crashes with 1000+ tables
- [ ] Code is clean and tested

### Phase 8 Complete (IntelliSense):
- [ ] Type `Employees.` → see columns <100ms
- [ ] Schema auto-detection works
- [ ] Alias resolution works
- [ ] No VimScript in hot path

## Quick Reference

### Connection String Formats

```lua
-- SQL Server
"sqlserver://localhost/vim_dadbod_test"
"sqlserver://user:pass@server\\SQLEXPRESS/database"

-- PostgreSQL
"postgres://localhost:5432/mydb"

-- MySQL
"mysql://localhost:3306/mydb"

-- SQLite
"sqlite://./local.db"
```

### Configuration Example

```lua
require('ssns').setup({
  connections = {
    dev_mssql = 'sqlserver://localhost/DevDB',
    dev_pg = 'postgres://localhost:5432/devdb',
    dev_mysql = 'mysql://localhost:3306/myapp',
  },
  ui = {
    position = 'left',
    width = 40,
    ssms_style = true,
  },
  cache = {
    ttl = 300,
  }
})
```

## Current Status

**Phase**: Getting started
**Focus**: Implement base classes and adapter system
**Priority**: SQL Server support first
**Goal**: Working UI before IntelliSense

## Important Notes

1. **UI before IntelliSense** - Don't start Phase 8 until Phase 7 complete
2. **Read INTELLISENSE_IMPLEMENTATION_GUIDE.md** - Learn from previous mistakes
3. **Multi-database from start** - Universal classes + adapters
4. **Type safety** - LuaLS annotations mandatory
5. **Test as you go** - Unit tests for each class

## Documentation Guidelines

**IMPORTANT: Do NOT create new documentation files without user approval!**

### ✅ DO:
- **Update existing markdown files** when requirements change
- **Update SSNS_ROADMAP.md** to track completed phases and tasks
- **Update SSNS_ARCHITECTURE.md** if class structure changes
- **Focus on code implementation** and conversation
- **Ask user before creating any new .md files**

### ❌ DON'T:
- **Don't create summary documents** after every update (wastes tokens)
- **Don't create implementation guides** without asking first
- **Don't create progress reports** or status documents
- **Don't duplicate information** that already exists in roadmap/architecture docs

**Keep documentation lean and up-to-date rather than creating new files!**

---

**Let's build SSNS the right way!** 🚀
