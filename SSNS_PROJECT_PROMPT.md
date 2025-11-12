# SSNS (SQL Server NeoVim Studio) - Project Kickoff

## Overview

I'm creating **SSNS**, a complete Lua rewrite of my VimScript vim-dadbod-ui plugin. This will be a modern Neovim-only SQL database management plugin with SSMS-style interface and IntelliSense completion.

## Background

**Current State**:
- `main` branch: Working SSMS-style VimScript plugin with enhanced server browsing
- `IntelliSense` branch: Attempted auto-completion (partial success, architectural issues)
- Plugin works but mixing VimScript + Lua causing type conversion nightmares

**Why Rewrite**:
- VimScript ↔ Lua boundary crossing kills performance
- Data duplication between UI cache and completion cache
- Type conversion bugs constantly breaking features
- Want modern async Neovim features (vim.loop, TreeSitter)
- Clean architecture for long-term maintenance

## Project Structure

```
ssns/  (NEW plugin directory, separate from vim-dadbod-ui)
├── lua/
│   ├── ssns/
│   │   ├── init.lua           # Plugin setup
│   │   ├── config.lua         # User configuration
│   │   ├── cache.lua          # Single source of truth
│   │   ├── connection.lua     # DB connections
│   │   ├── ui/
│   │   │   ├── tree.lua       # SSMS-style tree renderer
│   │   │   └── highlights.lua
│   │   ├── adapters/
│   │   │   └── sqlserver.lua  # SQL Server queries
│   │   └── completion/
│   │       ├── context.lua    # SQL parsing
│   │       └── source.lua     # Blink.cmp integration
│   └── blink/cmp/sources/ssns.lua
├── doc/ssns.txt
└── README.md
```

## Reference Materials

**In vim-dadbod-ui directory**:
1. `INTELLISENSE_IMPLEMENTATION_GUIDE.md` - **Critical lessons learned** from IntelliSense branch
2. `autoload/db_ui.vim` - VimScript UI implementation (reference for tree structure)
3. `autoload/db_ui/schemas.vim` - Database queries for different DB types
4. `autoload/db_ui/completion.vim` - Completion logic (see what NOT to do)

## Core Requirements

### 1. Hierarchical Cache (Week 1 Priority)

**Single source of truth** for both UI and completion:

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
                  columns = {...}  -- Lazy loaded
                }
              },
              views = {...},
              procedures = {...}
            }
          }
        }
      }
    }
  }
}
```

**Key Features**:
- TTL-based expiration (configurable)
- Lazy loading (columns/indexes only when needed)
- Eager loading (databases/schemas/tables on connect)
- Thread-safe async updates
- Event system for UI sync

### 2. SSMS-Style UI

**Tree Structure**:
```
▾  SQLEXPRESS ✓
    New query
   ▸  Buffers (1)
   ▸  Saved queries (0)
   ▾  Databases (2)
      ▾  vim_dadbod_test ✓
         ▾  TABLES (4)
            ▾  [dbo].[Employees]
                SELECT
                Columns
                    EmployeeID | int | NOT NULL | PK
                    FirstName  | nvarchar(50) | NOT NULL
                Indexes (0)
                Keys (0)
                DROP
         ▸  VIEWS (1)
         ▸  PROCEDURES (2)
         ▸  FUNCTIONS (0)
```

**Features**:
- Objects grouped by type (TABLES, VIEWS, etc.)
- Schema-qualified names `[schema].[object]`
- Lazy expand with loading indicator
- Right-click context menus
- Icons with nvim-web-devicons

### 3. IntelliSense Completion

**Context-Aware**:
- `DatabaseName.` → schemas
- `SchemaName.` → tables/views
- `TableName.` → columns
- Alias support: `FROM Employees e WHERE e.` → columns

**Critical Requirements** (from lessons learned):
- ✅ Pure Lua, zero VimScript in hot path
- ✅ <100ms response time
- ✅ Cross-schema table search (auto-detect schema)
- ✅ Handle 1000+ tables without lag
- ✅ Async everything

### 4. Database Adapters

**SQL Server** (primary focus):
```lua
-- lua/ssns/adapters/sqlserver.lua
return {
  query_tables = function(conn, db_name)
    return [[
      SET NOCOUNT ON;
      SELECT table_schema, table_name
      FROM INFORMATION_SCHEMA.TABLES
      WHERE table_type = 'BASE TABLE'
    ]]
  end,

  query_columns = function(conn, schema, table)
    -- Return columns with PK/FK info
  end,

  -- ... other queries
}
```

Support later: PostgreSQL, MySQL

## Critical Lessons from IntelliSense Branch

**Read INTELLISENSE_IMPLEMENTATION_GUIDE.md before starting!**

Key takeaways:
1. **Database name bug**: Don't confuse connection name with database name
2. **Trigger context**: Fetch actual line from buffer, ctx.line may be incomplete
3. **Type conversion**: Never mix string/table formats
4. **Cache timing**: Populate eagerly, don't rely on lazy loading for core data
5. **SET NOCOUNT ON**: Required for SQL Server to suppress row count messages

## Development Phases

### Phase 1: Foundation (Week 1)
- [ ] Cache structure with type annotations
- [ ] SQL Server adapter with async queries
- [ ] Connection management
- [ ] Unit tests for cache operations

### Phase 2: IntelliSense (Week 2)
- [ ] SQL context detection (consider TreeSitter)
- [ ] Blink.cmp source (pure Lua)
- [ ] Fuzzy matching
- [ ] Integration tests

### Phase 3: UI (Week 3)
- [ ] Tree renderer reading from cache
- [ ] SSMS-style grouping
- [ ] Keymaps and actions
- [ ] Loading indicators

### Phase 4: Polish (Week 4)
- [ ] Error handling
- [ ] User documentation
- [ ] Migration guide from vim-dadbod-ui
- [ ] Performance optimization

## Testing Strategy

**Test Database** (vim_dadbod_test):
- Multiple schemas (dbo, hr)
- Tables with various column types
- Views, procedures, functions
- Foreign keys, indexes

**Test Cases**:
1. Cache population on connect
2. Lazy loading columns
3. TTL expiration
4. Completion context detection
5. UI rendering performance

## Configuration Example

```lua
require('ssns').setup({
  connections = {
    dev = 'sqlserver://localhost/DevDB',
  },

  intellisense = {
    enabled = true,
    cache_ttl = 300,
    auto_fetch = true,
    show_system_objects = false,
  },

  ui = {
    ssms_style = true,
    show_schema_prefix = true,
    auto_expand_db = false,
  }
})
```

## Success Criteria

- [ ] Connect to SQL Server
- [ ] Browse server → database → schema → table hierarchy
- [ ] Type `Employees.` → see columns in <100ms
- [ ] Expand table in UI → see columns/indexes
- [ ] Cache persists across buffer switches
- [ ] Zero VimScript in completion path
- [ ] Works with 1000+ tables
- [ ] Clear error messages
- [ ] Documentation complete

## First Steps

1. Read `INTELLISENSE_IMPLEMENTATION_GUIDE.md` thoroughly
2. Create `lua/ssns/cache.lua` with hierarchical structure
3. Implement `cache.get()`, `cache.set()`, `cache.invalidate()`
4. Add LuaLS type annotations
5. Write unit tests

## Questions?

Before starting:
- [ ] Should we use TreeSitter for SQL parsing or stick with regex?
- [ ] Cache persistence to disk between sessions?
- [ ] Support multiple databases simultaneously?
- [ ] Provide SQL LSP server for broader editor support?

---

**Let's build this right from the ground up!** 🚀
