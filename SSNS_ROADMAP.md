# SSNS Development Roadmap - UI First Approach

## Project Goal

Convert vim-dadbod-ui (VimScript) to SSNS (Pure Lua) with **class-based architecture**.

**Priority**: Get UI working first, IntelliSense later.

---

## Phase 1: Class Hierarchy (Week 1)

### Goal
Implement complete class structure with proper OOP patterns.

### Tasks

#### 1.1 Base Infrastructure
- [ ] `lua/ssns/classes/base.lua` - BaseDbObject abstract class
  - [ ] Constructor with metadata
  - [ ] Parent/child references
  - [ ] `get_full_path()` method
  - [ ] `is_stale()` TTL checking
  - [ ] `refresh()` reload mechanism
  - [ ] `get_children()` iterator
  - [ ] UI state separation

#### 1.2 Core Classes
- [ ] `lua/ssns/classes/server.lua` - ServerClass
  - [ ] Connection management
  - [ ] Connection states (disconnected, connecting, connected, error)
  - [ ] `connect()`, `disconnect()`, `test_connection()`
  - [ ] `load_databases()` method

- [ ] `lua/ssns/classes/database.lua` - DbClass
  - [ ] `load_schemas()` method
  - [ ] `load_synonyms()` method
  - [ ] `find_schema()` lookup
  - [ ] `get_default_schema()` helper

- [ ] `lua/ssns/classes/schema.lua` - SchemaClass
  - [ ] `load_tables()`, `load_views()`, `load_procedures()`, `load_functions()`
  - [ ] `find_table()` lookup
  - [ ] `get_objects_by_type()` filter

- [ ] `lua/ssns/classes/table.lua` - TableClass
  - [ ] Lazy column loading
  - [ ] Lazy index loading
  - [ ] `get_columns()`, `get_indexes()`
  - [ ] `find_column()` lookup
  - [ ] `generate_select()`, `generate_insert()` helpers

- [ ] `lua/ssns/classes/view.lua` - ViewClass
  - [ ] Column loading
  - [ ] `get_definition()` method

- [ ] `lua/ssns/classes/procedure.lua` - ProcedureClass
  - [ ] Parameter loading
  - [ ] `generate_exec()` helper

- [ ] `lua/ssns/classes/function.lua` - FunctionClass
  - [ ] Parameter loading
  - [ ] Return type handling

- [ ] `lua/ssns/classes/synonym.lua` - SynonymClass
  - [ ] Target parsing
  - [ ] `resolve()` to actual object
  - [ ] `get_columns()` delegation

#### 1.3 Supporting Classes
- [ ] `lua/ssns/classes/column.lua` - ColumnClass
  - [ ] `get_full_type()` formatting
  - [ ] `is_primary_key()`, `is_foreign_key()` checks
  - [ ] `get_foreign_key_target()` resolution

- [ ] `lua/ssns/classes/index.lua` - IndexClass
  - [ ] Column list management
  - [ ] `covers_columns()` optimization check

- [ ] `lua/ssns/classes/parameter.lua` - ParameterClass
  - [ ] Direction handling (IN/OUT/INOUT)
  - [ ] Type formatting

- [ ] `lua/ssns/classes/constraint.lua` - Constraint classes
  - [ ] PrimaryKeyClass
  - [ ] ForeignKeyClass
  - [ ] CheckConstraintClass

#### 1.4 Factory & Cache
- [ ] `lua/ssns/factory.lua` - Object creation
  - [ ] `create_server()`
  - [ ] `create_database()`
  - [ ] `create_schema()`
  - [ ] `create_table()`, etc.

- [ ] `lua/ssns/cache.lua` - Global cache manager
  - [ ] `servers` array
  - [ ] `add_server()`, `remove_server()`
  - [ ] `find_server()`, `find_database()`, etc.
  - [ ] `clear_all()`, `refresh_all()`

#### 1.5 Testing
- [ ] Unit tests for each class
- [ ] Test parent/child navigation
- [ ] Test lazy loading
- [ ] Test TTL expiration

**Deliverable**: Complete class hierarchy with tests passing.

---

## Phase 2: Adapter System (Week 1-2)

### Goal
Implement database-agnostic adapter pattern with SQL Server as first implementation.

**See SSNS_MULTI_DATABASE.md for complete multi-database architecture!**

### Tasks

#### 2.1 Adapter Structure
- [ ] `lua/ssns/adapters/base.lua` - Base adapter interface with features
- [ ] `lua/ssns/adapters/factory.lua` - Create adapter from connection string
- [ ] `lua/ssns/adapters/sqlserver.lua` - SQL Server implementation (priority 1)
- [ ] `lua/ssns/adapters/postgres.lua` - PostgreSQL implementation (future)
- [ ] `lua/ssns/adapters/mysql.lua` - MySQL implementation (future)
- [ ] `lua/ssns/adapters/sqlite.lua` - SQLite implementation (future)

#### 2.2 Query Functions
- [ ] `query_databases()` - List all databases on server
  ```sql
  SELECT name FROM sys.databases
  WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
  ```

- [ ] `query_schemas()` - List schemas in database
  ```sql
  SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA
  WHERE schema_name NOT IN ('sys', 'INFORMATION_SCHEMA')
  ```

- [ ] `query_tables()` - List tables in schema
  ```sql
  SET NOCOUNT ON;
  SELECT table_schema, table_name
  FROM INFORMATION_SCHEMA.TABLES
  WHERE table_type = 'BASE TABLE'
    AND table_schema = @schema
  ```

- [ ] `query_views()` - List views in schema
- [ ] `query_procedures()` - List procedures in schema
- [ ] `query_functions()` - List functions in schema
- [ ] `query_synonyms()` - List synonyms in database

- [ ] `query_columns()` - Get columns for table
  ```sql
  SET NOCOUNT ON;
  SELECT
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.numeric_precision,
    c.numeric_scale,
    c.is_nullable,
    c.column_default,
    CASE WHEN pk.column_name IS NOT NULL THEN 1 ELSE 0 END as is_pk,
    c.ordinal_position
  FROM INFORMATION_SCHEMA.COLUMNS c
  LEFT JOIN ... -- PK join
  WHERE c.table_schema = @schema AND c.table_name = @table
  ORDER BY c.ordinal_position
  ```

- [ ] `query_indexes()` - Get indexes for table
- [ ] `query_foreign_keys()` - Get FKs for table
- [ ] `query_parameters()` - Get parameters for procedure/function

#### 2.3 Result Parsing
- [ ] Parse query results into class instances
- [ ] Handle SQL Server data types
- [ ] Handle NULL values
- [ ] Error handling for failed queries

#### 2.4 Async Execution
- [ ] Use `vim.loop` for non-blocking queries
- [ ] Queue management for multiple queries
- [ ] Loading indicators during fetch

**Deliverable**: SQL Server adapter with all queries working.

---

## Phase 3: Connection Management (Week 2)

### Goal
Handle database connections reliably.

### Tasks

#### 3.1 Connection Module
- [ ] `lua/ssns/connection.lua`
  - [ ] Parse connection strings
  - [ ] Use vim-dadbod for actual connections
  - [ ] Connection pooling/reuse
  - [ ] Connection state tracking

#### 3.2 Connection String Formats
- [ ] SQL Server: `sqlserver://server/database`
- [ ] SQL Server with auth: `sqlserver://user:pass@server/database`
- [ ] Named instances: `sqlserver://server\\SQLEXPRESS/database`

#### 3.3 Error Handling
- [ ] Connection timeout handling
- [ ] Authentication errors
- [ ] Network errors
- [ ] Graceful fallback

**Deliverable**: Reliable connection management.

---

## Phase 4: UI Tree Renderer (Week 2-3)

### Goal
Render class hierarchy in Neovim buffer as SSMS-style tree.

### Tasks

#### 4.1 Tree Buffer
- [ ] `lua/ssns/ui/buffer.lua`
  - [ ] Create buffer with proper options
  - [ ] Set buffer name, filetype
  - [ ] Make read-only
  - [ ] Handle buffer close/delete

#### 4.2 Tree Rendering
- [ ] `lua/ssns/ui/tree.lua`
  - [ ] Render server nodes
  - [ ] Render database nodes with connection status (✓)
  - [ ] Render schema nodes
  - [ ] Render object type groups (TABLES, VIEWS, etc.)
  - [ ] Render individual objects
  - [ ] Render object details (columns, indexes, etc.)

#### 4.3 Tree Format
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
               ▾  Columns
                   EmployeeID   | int      | NOT NULL | PK
                   FirstName    | nvarchar(50) | NOT NULL
                   LastName     | nvarchar(50) | NOT NULL
               ▸  Indexes (0)
               ▸  Keys (1)
                DROP
         ▸  VIEWS (1)
         ▸  PROCEDURES (2)
         ▸  FUNCTIONS (0)
         ▸  SYNONYMS (0)
```

#### 4.4 Icons & Highlights
- [ ] `lua/ssns/ui/highlights.lua`
  - [ ] Define highlight groups
  - [ ] Icon definitions (nerd fonts)
  - [ ] Color scheme integration

#### 4.5 Indentation & Folding
- [ ] Proper indentation levels
- [ ] Expand/collapse indicators (▸ ▾)
- [ ] Nested object rendering

**Deliverable**: Working tree display reading from classes.

---

## Phase 5: User Interactions (Week 3)

### Goal
Handle expand/collapse, actions, keymaps.

### Tasks

#### 5.1 Expand/Collapse
- [ ] Detect line under cursor
- [ ] Map line to class instance
- [ ] Toggle `ui_state.expanded`
- [ ] Re-render tree
- [ ] Lazy load children on expand

#### 5.2 Actions
- [ ] **SELECT** - Generate SELECT query for table
- [ ] **EXEC** - Generate EXEC for procedure
- [ ] **New query** - Open new query buffer
- [ ] **DROP** - Generate DROP statement (with confirmation)
- [ ] **Refresh** - Reload object metadata

#### 5.3 Keymaps
```lua
-- In tree buffer
<CR>    - Expand/collapse or execute action
o       - Open object in new query
r       - Refresh current node
R       - Refresh all
d       - Toggle database connection
q       - Close tree
?       - Show help
```

#### 5.4 Context Menus
- [ ] Right-click menu (if terminal supports)
- [ ] Action selection
- [ ] Object-specific actions

**Deliverable**: Interactive tree with all actions working.

---

## Phase 6: Query Buffers (Week 3-4)

### Goal
Create and manage SQL query buffers.

### Tasks

#### 6.1 Query Buffer Creation
- [ ] `lua/ssns/ui/query.lua`
  - [ ] Create new buffer
  - [ ] Set SQL filetype
  - [ ] Attach to database connection
  - [ ] Set buffer variables (`b:ssns_db_key`, etc.)

#### 6.2 Query Execution
- [ ] Execute selection or current statement
- [ ] Show results in split/float
- [ ] Format results table
- [ ] Handle errors gracefully

#### 6.3 Results Display
- [ ] Table format with borders
- [ ] Column alignment
- [ ] Row numbering
- [ ] Copy to clipboard

#### 6.4 Saved Queries
- [ ] Save query to file
- [ ] Load saved query
- [ ] Organize by connection
- [ ] Recent queries list

**Deliverable**: Full query execution workflow.

---

## Phase 7: Configuration & Polish (Week 4)

### Goal
User configuration, documentation, testing.

### Tasks

#### 7.1 Configuration
- [ ] `lua/ssns/config.lua`
  ```lua
  require('ssns').setup({
    connections = {
      dev = 'sqlserver://localhost/DevDB',
    },
    ui = {
      position = 'left',  -- left, right, float
      width = 40,
      ssms_style = true,
      show_schema_prefix = true,
      icons = {
        server = '',
        database = '',
        table = '',
        view = '',
        -- ...
      }
    },
    cache = {
      ttl = 300,  -- 5 minutes
    }
  })
  ```

#### 7.2 Commands
- [ ] `:SSNS` - Toggle tree
- [ ] `:SSNSConnect <name>` - Connect to saved connection
- [ ] `:SSNSRefresh` - Refresh all
- [ ] `:SSNSQuery` - New query buffer

#### 7.3 Documentation
- [ ] `doc/ssns.txt` - Vim help file
- [ ] README.md - Installation, usage, screenshots
- [ ] MIGRATION.md - Guide from vim-dadbod-ui

#### 7.4 Testing
- [ ] Integration tests with test database
- [ ] Performance benchmarks
- [ ] Error scenario testing

**Deliverable**: Production-ready plugin.

---

## Phase 8: IntelliSense (Week 5+) - LATER

**Only start after UI is complete!**

### Goal
Add blink.cmp integration for SQL completion.

### Tasks
- [ ] Read `INTELLISENSE_IMPLEMENTATION_GUIDE.md`
- [ ] Implement context detection
- [ ] Create blink.cmp source
- [ ] Use existing class hierarchy for lookups
- [ ] Add fuzzy matching
- [ ] Performance optimization

**Reference**: See separate IntelliSense guide.

---

## Success Criteria (Before IntelliSense)

- [ ] Can connect to SQL Server
- [ ] Tree displays all database objects
- [ ] Expand/collapse works smoothly
- [ ] Can view table columns/indexes
- [ ] Can execute SELECT on table
- [ ] Can execute stored procedure
- [ ] Query buffers work
- [ ] Results display properly
- [ ] Saved queries work
- [ ] No crashes or errors
- [ ] Performance acceptable (1000+ tables)

---

## Migration from vim-dadbod-ui

### What to Reference

**VimScript Implementation** (vim-dadbod-ui):
- `autoload/db_ui.vim` - Tree structure, object population
- `autoload/db_ui/drawer.vim` - UI rendering
- `autoload/db_ui/schemas.vim` - SQL queries
- `autoload/db_ui/query.vim` - Query buffer management

**Convert to Lua**:
- Tree structure → Class hierarchy
- VimScript functions → Lua methods
- Drawer rendering → `ui/tree.lua`
- Query execution → `ui/query.lua`

### What NOT to Port

- Don't port completion code yet (Phase 8)
- Don't port old caching system (use class-based)
- Don't port VimScript buffer variables (use Lua state)

---

## Development Workflow

1. **Start with classes** - Get object model right
2. **Add adapter** - Populate classes from DB
3. **Render tree** - Display classes in UI
4. **Add interactions** - Make it usable
5. **Polish** - Config, docs, tests
6. **IntelliSense** - After everything else works

---

## Questions Before Starting

1. **TreeSitter SQL parser** for query execution context?
   - Probably overkill for UI, useful for IntelliSense later

2. **Cache persistence** to disk between sessions?
   - Maybe, but not priority

3. **Multi-database support** (SQL Server + PostgreSQL)?
   - Start with SQL Server only, add adapters later

4. **Floating window** vs sidebar?
   - Configurable, default sidebar like SSMS

---

**Ready to build SSNS the right way!** 🚀
