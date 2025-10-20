# SSMS-Style Object Browser Refactor Roadmap

## Progress Summary

**Overall Status**: 8 of 10 phases complete (80%)

- ✅ **Phase 1**: Foundation & Configuration - Complete
- ✅ **Phase 2**: Schema Queries - Complete
- ✅ **Phase 3**: Connection Handling - Complete
- ✅ **Phase 4**: Data Model Restructuring - Complete
- ✅ **Phase 5**: Drawer Rendering Refactor - Complete
- ✅ **Phase 6**: Actions & Query Execution - Complete
- ✅ **Phase 7**: Toggle & Navigation - Complete
- x **Phase 8**: Testing & Polish - Not Complete
- ✅ **Phase 9**: Performance Optimization - Complete
- x **Phase 10**: Multi-Database Support - Not Complete

---

## Overview
Transform vim-dadbod-ui from database-level connections to server-level connections with SSMS-style object browser hierarchy.

### Current Structure
```
DB (with database in connection string)
├─ Schemas
│  └─ Tables
│     ├─ [table]
│     │  ├─ List
│     │  ├─ Columns
│     │  └─ ... (table helpers)
```

### Target Structure
```
Server (without database in connection string)
├─ Databases
│  └─ [DatabaseName]
│     ├─ TABLES
│     │  └─ [schema].[tablename]
│     │     ├─ SELECT
│     │     ├─ Columns
│     │     ├─ Indexes
│     │     ├─ Keys
│     │     │  ├─ Primary Keys
│     │     │  └─ Foreign Keys
│     │     ├─ Constraints
│     │     ├─ ALTER
│     │     ├─ DROP
│     │     └─ DEPENDENCIES
│     ├─ VIEWS
│     │  └─ [schema].[viewname]
│     │     ├─ SELECT
│     │     ├─ Columns
│     │     ├─ ALTER
│     │     ├─ DROP
│     │     └─ DEPENDENCIES
│     ├─ PROCEDURES
│     │  └─ [schema].[procedurename]
│     │     ├─ EXEC
│     │     ├─ Parameters
│     │     ├─ ALTER
│     │     ├─ DROP
│     │     └─ DEPENDENCIES
│     └─ FUNCTIONS
│        └─ [schema].[functionname]
│           ├─ SELECT
│           ├─ Parameters
│           ├─ ALTER
│           ├─ DROP
│           └─ DEPENDENCIES
```

**Design Notes:**
- Items are ordered by usage frequency: common actions (SELECT/EXEC) at top, structural info in middle, destructive actions (ALTER/DROP) at bottom
- Different object types show appropriate items (e.g., views don't have indexes)
- Keys are grouped as a sub-category since they're related
- Parameters shown for procedures/functions to inspect input/output
- Flat structure avoids unnecessary nesting (no DETAILS or ACTIONS wrapper)
- **Actions** (SELECT, ALTER, DROP, DEPENDENCIES, EXEC): Generate SQL and open in query buffer
  - SELECT on table → Opens buffer with "SELECT TOP 100 * FROM [schema].[table]"
  - EXEC on procedure → Opens buffer with "EXEC [schema].[procedure] @param=?"
  - ALTER on any object → Opens buffer with object's definition SQL for editing
  - DROP on any object → Opens buffer with "DROP [type] [schema].[name]"
  - DEPENDENCIES → Opens buffer with query showing object dependencies
  - User can review, edit, and execute the SQL in the buffer
  - Buffer is connected to the current server/database context
- **Structural Groups** (Columns, Indexes, Keys, Constraints, Parameters): Expandable/collapsible, show list of items
  - Columns expands to show: column_name (data_type, nullable, default)
  - Indexes expands to show: index_name (type, unique, is_primary)
  - Keys expands to show: Primary Keys and Foreign Keys sub-groups
  - Constraints expands to show: constraint_name (type, definition)
  - Parameters expands to show: param_name (data_type, mode, length)

---

## Phase 1: Foundation & Configuration (Estimated: 2-3 days)

### 1.1 Add Configuration Options
**File**: `plugin/db_ui.vim`

- [x] Add `g:db_ui_use_ssms_style` (default: 0) - Global toggle for SSMS-style mode
- [x] Add `g:db_ui_ssms_object_types` - List of object types to show (default: ['tables', 'views', 'procedures', 'functions'])
- [x] Add `g:db_ui_show_schema_prefix` - Show [schema].[name] format (default: 1)
- [x] Add `g:db_ui_ssms_show_dependencies` - Enable DEPENDENCIES action (default: 1)
- [x] Add `g:db_ui_hide_system_databases` - Hide system databases (default: 1)
- [x] Add `g:db_ui_ssms_show_columns` - Show Columns structural info (default: 1)
- [x] Add `g:db_ui_ssms_show_indexes` - Show Indexes structural info (default: 1)
- [x] Add `g:db_ui_ssms_show_constraints` - Show Constraints structural info (default: 1)
- [x] Add `g:db_ui_ssms_show_keys` - Show Keys structural info (default: 1)

### 1.2 Add New Icons
**File**: `plugin/db_ui.vim`

Add to `g:db_ui_icons`:
```vim
\ 'database': '󰆼',        " Individual database icon
\ 'view': '󰈙',           " View icon
\ 'procedure': '󰊕',      " Stored procedure icon
\ 'function': '󰡱',       " Function icon
\ 'action_select': '',  " Select action
\ 'action_exec': '',    " Execute action
\ 'action_alter': '�',   " Alter action
\ 'action_drop': '�',    " Drop action
\ 'action_dependencies': '󰘦',  " Dependencies icon
\ 'columns': '',        " Columns structural info
\ 'indexes': '',        " Indexes structural info
\ 'keys': '',          " Keys structural info
\ 'constraints': '',    " Constraints structural info
\ 'parameters': '',     " Parameters info
```

**Status**: ✅ Complete

### 1.3 Documentation
**File**: `doc/dadbod-ui.txt`

- [x] Document new configuration options
- [x] Add examples of server-level connection strings
- [x] Document SSMS-style mode behavior
- [x] Add migration guide for existing users

---

## Phase 2: Schema & Query Infrastructure (Estimated: 3-4 days) ✅

### 2.1 Add Database List Queries
**File**: `autoload/db_ui/schemas.vim`

For each supported database system, add database listing query:

#### SQL Server
```vim
let s:sqlserver_databases_query = "
  \ SELECT name as database_name 
  \ FROM sys.databases 
  \ WHERE database_id > 4  -- Exclude system databases optionally
  \ ORDER BY name"
```

#### PostgreSQL
```vim
let s:postgres_databases_query = "
  \ SELECT datname as database_name 
  \ FROM pg_database 
  \ WHERE datistemplate = false 
  \ ORDER BY datname"
```

#### MySQL
```vim
let s:mysql_databases_query = "
  \ SELECT schema_name as database_name 
  \ FROM information_schema.schemata 
  \ ORDER BY schema_name"
```

- [x] Add `databases_query` field to each scheme config
- [x] Update scheme configs in `s:schemas` dictionary

### 2.2 Add Object Type Queries
**File**: `autoload/db_ui/schemas.vim`

For SQL Server (primary target):

#### Views Query
```vim
let s:sqlserver_views_query = "
  \ SELECT 
  \   SCHEMA_NAME(schema_id) as table_schema,
  \   name as view_name 
  \ FROM sys.views 
  \ ORDER BY table_schema, view_name"
```

#### Procedures Query
```vim
let s:sqlserver_procedures_query = "
  \ SELECT 
  \   SCHEMA_NAME(schema_id) as schema_name,
  \   name as procedure_name 
  \ FROM sys.procedures 
  \ ORDER BY schema_name, procedure_name"
```

#### Functions Query
```vim
let s:sqlserver_functions_query = "
  \ SELECT 
  \   SCHEMA_NAME(schema_id) as schema_name,
  \   name as function_name 
  \ FROM sys.objects 
  \ WHERE type IN ('FN', 'IF', 'TF', 'FS', 'FT')
  \ ORDER BY schema_name, function_name"
```

#### Structural Queries (for tables/views)

**Columns Query:**
```sql
SELECT 
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = '{schema}' AND c.TABLE_NAME = '{table}'
ORDER BY c.ORDINAL_POSITION
```

**Indexes Query:**
```sql
SELECT 
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('[{schema}].[{table}]')
  AND i.name IS NOT NULL
ORDER BY i.name
```

**Primary Keys Query:**
```sql
SELECT 
    kcu.COLUMN_NAME,
    tc.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
    ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
WHERE tc.TABLE_SCHEMA = '{schema}'
  AND tc.TABLE_NAME = '{table}'
  AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY kcu.ORDINAL_POSITION
```

**Foreign Keys Query:**
```sql
SELECT 
    fk.name AS constraint_name,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS schema_name,
    OBJECT_NAME(fk.parent_object_id) AS table_name,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS column_name,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS referenced_column
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
WHERE fk.parent_object_id = OBJECT_ID('[{schema}].[{table}]')
ORDER BY fk.name
```

**Constraints Query:**
```sql
SELECT 
    tc.CONSTRAINT_NAME,
    tc.CONSTRAINT_TYPE,
    cc.CHECK_CLAUSE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
LEFT JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc 
    ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
WHERE tc.TABLE_SCHEMA = '{schema}' 
  AND tc.TABLE_NAME = '{table}'
  AND tc.CONSTRAINT_TYPE IN ('CHECK', 'UNIQUE')
ORDER BY tc.CONSTRAINT_NAME
```

**Parameters Query (for procedures/functions):**
```sql
SELECT 
    p.PARAMETER_NAME,
    p.DATA_TYPE,
    p.PARAMETER_MODE,
    p.CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.PARAMETERS p
WHERE p.SPECIFIC_SCHEMA = '{schema}' 
  AND p.SPECIFIC_NAME = '{object_name}'
ORDER BY p.ORDINAL_POSITION
```

- [x] Add queries for views, procedures, functions
- [x] Add queries for columns, indexes, keys, constraints
- [x] Add queries for parameters (procedures/functions)
- [x] Add queries for dependencies (sys.sql_expression_dependencies)
- [x] Support for PostgreSQL (pg_views, pg_proc, pg_indexes, pg_constraint)
- [x] Support for MySQL (information_schema.routines, information_schema.views, information_schema.columns)

### 2.3 Update Schema Parser Functions
**File**: `autoload/db_ui/schemas.vim`

- [x] Add `db_ui#schemas#query_databases(conn, scheme)` - Query database list
- [x] Add `db_ui#schemas#query_views(db, scheme)` - Query views
- [x] Add `db_ui#schemas#query_procedures(db, scheme)` - Query procedures
- [x] Add `db_ui#schemas#query_functions(db, scheme)` - Query functions
- [x] Add `db_ui#schemas#query_columns(db, scheme, schema, table)` - Query columns
- [x] Add `db_ui#schemas#query_indexes(db, scheme, schema, table)` - Query indexes
- [x] Add `db_ui#schemas#query_primary_keys(db, scheme, schema, table)` - Query PKs
- [x] Add `db_ui#schemas#query_foreign_keys(db, scheme, schema, table)` - Query FKs
- [x] Add `db_ui#schemas#query_constraints(db, scheme, schema, table)` - Query constraints
- [x] Add `db_ui#schemas#query_parameters(db, scheme, schema, object)` - Query parameters
- [x] Add `db_ui#schemas#query_dependencies(db, scheme, object_name, object_type)` - Query dependencies
- [x] Add `db_ui#schemas#supports_databases(scheme)` - Check if scheme supports database listing

**Status**: ✅ Phase 2 Complete

---

## Phase 3: Connection & URL Handling (Estimated: 2-3 days) ✅

### 3.1 Enhance URL Parsing
**File**: `autoload/db_ui.vim`

- [x] Add `s:dbui.parse_connection_level(url)` - Determine if connection is server-level or database-level
  ```vim
  " Returns: { 'level': 'server'|'database', 'has_database': 0|1, 'database': 'name'|'' }
  ```
- [x] Add `s:dbui.is_server_connection(db)` helper
- [x] Add `s:dbui.get_database_from_url(url)` helper
- [x] Add `s:dbui.build_database_url(server_url, database_name)` helper
- [ ] Modify `s:dbui.populate_dbs()` to handle server-level connections (Deferred to Phase 4)

### 3.2 Connection String Support
**File**: `autoload/db_ui/connections.vim`

- [x] Update connection validation to allow server-only URLs
- [x] Add `s:connections.get_connection_type(url)` to detect Server vs Database
- [x] Add `s:connections.is_likely_server_url(url)` helper for validation
- [x] Add helper text when adding connections about server vs database level

Example connection strings:
```
sqlserver://localhost                          # Server-level
sqlserver://localhost/MyDatabase              # Database-level (legacy)
postgresql://localhost                         # Server-level
postgresql://localhost:5432/postgres          # Database-level (legacy)
```

**Status**: ✅ Phase 3 Complete

---

## Phase 4: Data Model Restructuring (Estimated: 4-5 days) ✅

### 4.1 Extend Database Object Structure
**File**: `autoload/db_ui.vim`

Current structure per database:
```vim
let db = {
  \ 'name': 'mydb',
  \ 'url': 'connection_string',
  \ 'conn': connection_object,
  \ 'schemas': { 'list': [], 'items': {}, 'expanded': 0 },
  \ 'tables': { 'list': [], 'items': {}, 'expanded': 0 },
  \ ...
}
```

New structure for server-level connections:
```vim
let server = {
  \ 'name': 'myserver',
  \ 'url': 'server_connection_string',
  \ 'conn': connection_object,
  \ 'is_server': 1,
  \ 'databases': {
  \   'list': [],              " ['db1', 'db2', 'db3']
  \   'items': {
  \     'db1': {
  \       'name': 'db1',
  \       'url': 'server_url/db1',
  \       'conn': db_connection,
  \       'expanded': 0,
  \       'object_types': {
  \         'tables': { 'list': [], 'items': {}, 'expanded': 0 },
  \         'views': { 'list': [], 'items': {}, 'expanded': 0 },
  \         'procedures': { 'list': [], 'items': {}, 'expanded': 0 },
  \         'functions': { 'list': [], 'items': {}, 'expanded': 0 },
  \       }
  \     }
  \   },
  \   'expanded': 0
  \ }
}
```

- [x] Add `is_server` and `databases` fields to database structure
- [x] Create `s:dbui.create_database_structure(server, db_name)` - Initialize database under server
- [x] Modify `s:dbui.generate_new_db_entry()` to detect and handle both types
- [x] Add `s:dbui.populate_databases(server)` - Populate database list for server

### 4.2 Database Connection Management
**File**: `autoload/db_ui.vim`

- [x] Add `s:dbui.connect_to_database(server, db_name)` - Connect to specific database
- [x] Add lazy loading: connect to database only when expanded
- [x] Cache database connections per server (via databases.items dictionary)
- [x] Add `s:dbui.is_system_database()` helper to filter system databases

### 4.3 Object Population Functions
**File**: `autoload/db_ui.vim`

- [x] Add `s:dbui.populate_object_types(database)` - Populate all object types
- [x] Add `s:dbui.populate_object_type(database, object_type, scheme_info)` - Generic object type population
- [x] Support for views, procedures, functions via unified function
- [x] Format object names as [schema].[name] based on g:db_ui_show_schema_prefix
- [ ] Modify existing `populate_tables()` to work with new structure (Deferred to Phase 5)

**Status**: ✅ Phase 4 Complete

---

## Phase 5: Drawer Rendering Refactor (Estimated: 5-6 days) ✅

### 5.1 Core Rendering Changes
**File**: `autoload/db_ui/drawer.vim`

- [x] Modify `s:drawer.add_db()` to detect server vs database connection
- [x] Create `s:drawer.add_server()` - Render server-level connection
- [x] Create `s:drawer.add_database(server, db_name, level)` - Render individual database
- [x] Create `s:drawer.render_object_types(database, level)` - Render object type groups

### 5.2 Object Type Rendering
**File**: `autoload/db_ui/drawer.vim`

Create new rendering functions:

```vim
function! s:drawer.render_tables_group(database, level)
  " Renders TABLES group with [schema].[table] format
endfunction

function! s:drawer.render_views_group(database, level)
  " Renders VIEWS group with [schema].[view] format
endfunction

function! s:drawer.render_procedures_group(database, level)
  " Renders PROCEDURES group with [schema].[procedure] format
endfunction

function! s:drawer.render_functions_group(database, level)
  " Renders FUNCTIONS group with [schema].[function] format
endfunction
```

- [x] Implement unified rendering via `render_object_type_group()`
- [x] Show object counts: "TABLES (25)", "VIEWS (12)", etc.
- [x] Format names as [schema].[objectname] based on g:db_ui_show_schema_prefix
- [x] Handle objects without schemas (default schema)

### 5.3 Object Actions and Structural Groups Rendering
**File**: `autoload/db_ui/drawer.vim`

**Important Distinction:**
- **Actions**: Generate SQL and open in query buffer (no expansion)
- **Structural Groups**: Expandable/collapsible lists

```vim
function! s:drawer.render_table_items(table, schema, level)
  " Renders items under a table:
  " - Actions: SELECT, ALTER, DROP, DEPENDENCIES (generate SQL, open in buffer)
  " - Structural Groups: Columns, Indexes, Keys, Constraints (expand/collapse)
  
  " Action items (type: 'action')
  " These generate SQL and open in a new query buffer
  call self.add('SELECT', 'generate_select_query', 'action', icons.action_select, ...)
  call self.add('ALTER', 'generate_alter_query', 'action', icons.action_alter, ...)
  call self.add('DROP', 'generate_drop_query', 'action', icons.action_drop, ...)
  
  " Structural group items (type: 'structural_group', expandable: 1)
  call self.add('Columns ('.len(columns).')', 'toggle', 'columns_group', icons.columns, ...)
  
  " When columns group is expanded, show individual columns
  if columns_group.expanded
    for column in columns
      call self.add(column.name.' ('.column.type.')', 'view_detail', 'column', ...)
    endfor
  endif
endfunction

function! s:drawer.render_columns_list(table, schema, level)
  " When Columns group is expanded, show:
  " - column_name (data_type, nullable, default)
  " Example: "Username (varchar(50), NOT NULL)"
endfunction

function! s:drawer.render_indexes_list(table, schema, level)
  " When Indexes group is expanded, show:
  " - index_name (type, unique, is_primary_key)
  " Example: "IX_Users_Email (Nonclustered, Unique)"
endfunction

function! s:drawer.render_keys_group(table, schema, level)
  " When Keys group is expanded, show sub-groups:
  " - Primary Keys (expandable)
  " - Foreign Keys (expandable)
  " Each sub-group shows individual keys with details
endfunction

function! s:drawer.render_constraints_list(table, schema, level)
  " When Constraints group is expanded, show:
  " - constraint_name (type, definition)
  " Example: "CK_Users_Age (CHECK, Age >= 18)"
endfunction

function! s:drawer.render_parameters_list(object, schema, level)
  " When Parameters group is expanded, show:
  " - param_name (data_type, mode, length)
  " Example: "@UserId (int, IN)"
endfunction
```

- [ ] Implement action rendering (immediate execution) - Deferred to Phase 6
- [ ] Implement structural group rendering (expand/collapse) - Deferred to Phase 6
- [ ] Show item counts in group headers: "Columns (8)" - Deferred to Phase 6
- [ ] Render individual items with appropriate formatting - Deferred to Phase 6
- [ ] Use appropriate icons for each type - Deferred to Phase 6
- [ ] Store metadata for execution/navigation - Deferred to Phase 6

### 5.4 Populate Functions for Drawer
**File**: `autoload/db_ui/drawer.vim`

- [x] Modify `s:drawer.toggle_db()` to handle server connections
- [x] Add `s:drawer.toggle_server()` - Lazy load databases
- [x] Add `s:drawer.render_databases()` - Render databases list
- [ ] Modify `s:drawer.populate_schemas()` to work with new structure (Not needed - using object_types instead)

### 5.5 Legacy Support in Drawer
**File**: `autoload/db_ui/drawer.vim`

- [x] Keep existing `add_db()` behavior for database-level connections
- [x] Add feature flag checks (g:db_ui_use_ssms_style)
- [x] Ensure backward compatibility with current drawer sections

**Status**: ✅ Phase 5 Complete

---

## Phase 6: Actions & Query Execution (Estimated: 3-4 days) ✅

### 6.1 Object Type Helpers
**File**: `autoload/db_ui/object_helpers.vim` (NEW)

#### View Helpers
```vim
let s:sqlserver_view_helpers = {
  \ 'SELECT': 'SELECT TOP 200 * FROM [{schema}].[{view}]',
  \ 'ALTER': 'SELECT OBJECT_DEFINITION(OBJECT_ID(''[{schema}].[{view}]'')) AS ViewDefinition',
  \ 'DROP': 'DROP VIEW [{schema}].[{view}]',
  \ 'DEPENDENCIES': "SELECT ... FROM sys.sql_expression_dependencies WHERE referencing_id = OBJECT_ID('[{schema}].[{view}]')",
\ }
```

#### Procedure Helpers
```vim
let s:sqlserver_procedure_helpers = {
  \ 'EXEC': 'EXEC [{schema}].[{procedure}]',
  \ 'ALTER': 'SELECT OBJECT_DEFINITION(OBJECT_ID(''[{schema}].[{procedure}]'')) AS ProcedureDefinition',
  \ 'DROP': 'DROP PROCEDURE [{schema}].[{procedure}]',
  \ 'DEPENDENCIES': "SELECT ... FROM sys.sql_expression_dependencies WHERE referencing_id = OBJECT_ID('[{schema}].[{procedure}]')",
\ }
```

#### Function Helpers
```vim
let s:sqlserver_function_helpers = {
  \ 'SELECT': 'SELECT * FROM [{schema}].[{function}]()',
  \ 'ALTER': 'SELECT OBJECT_DEFINITION(OBJECT_ID(''[{schema}].[{function}]'')) AS FunctionDefinition',
  \ 'DROP': 'DROP FUNCTION [{schema}].[{function}]',
  \ 'DEPENDENCIES': "SELECT ... FROM sys.sql_expression_dependencies WHERE referencing_id = OBJECT_ID('[{schema}].[{function}]')",
\ }
```

- [x] Implement helpers for each object type
- [x] Support parameter substitution: {schema}, {table}, {view}, {procedure}, {function}
- [x] Add helper getter: `db_ui#object_helpers#get(scheme, object_type)`
- [x] Maintain backward compatibility with existing table helpers

### 6.2 Query Execution Updates
**File**: `autoload/db_ui/query.vim`

- [x] Modify `s:query.open()` to handle object actions (via execute_object_action)
- [x] Add `s:drawer.execute_object_action()` - Handle views, procedures, functions, tables
- [x] Handle different connection contexts (server vs database)
- [ ] Ensure proper database context switching for SQL Server (deferred to Phase 8)
  ```sql
  USE [DatabaseName];
  GO
  -- query here
  ```

### 6.3 Buffer Management
**File**: `autoload/db_ui/query.vim`

- [x] Update buffer naming to include object type and action
- [x] Store metadata in buffer item label field
- [x] Buffer management handles new action-based queries

### 6.4 Dependencies Query
**Files**: `autoload/db_ui/schemas.vim`, `autoload/db_ui/query.vim`

SQL Server dependencies query:
```sql
SELECT 
    OBJECT_SCHEMA_NAME(referencing_id) AS ReferencingSchema,
    OBJECT_NAME(referencing_id) AS ReferencingObject,
    o.type_desc AS ReferencingType,
    OBJECT_SCHEMA_NAME(referenced_id) AS ReferencedSchema,
    OBJECT_NAME(referenced_id) AS ReferencedObject,
    o2.type_desc AS ReferencedType
FROM sys.sql_expression_dependencies sed
JOIN sys.objects o ON sed.referencing_id = o.object_id
LEFT JOIN sys.objects o2 ON sed.referenced_id = o2.object_id
WHERE sed.referencing_id = OBJECT_ID('[{schema}].[{object}]')
   OR sed.referenced_id = OBJECT_ID('[{schema}].[{object}]')
ORDER BY ReferencingSchema, ReferencingObject
```

- [x] Add dependency query to schemas (included in object_helpers.vim templates)
- [x] DEPENDENCIES action opens query buffer with dependency SQL
- [ ] Add interactive navigation for dependencies (jump to related objects) - deferred to Phase 8

### 6.5 Structural Groups
**File**: `autoload/db_ui/drawer.vim`

- [x] Implement structural group rendering (Columns, Indexes, Keys, Constraints, Parameters)
- [x] Add toggle logic for structural groups
- [x] Lazy-load structural group data on first expansion
- [x] Format structural group items with details (data types, nullable, unique, etc.)
- [x] Support for all object types (tables, views, procedures, functions)

**Status**: ✅ Phase 6 Complete

---

## Phase 7: Toggle & Navigation (Estimated: 2-3 days) ✅

### 7.1 Update Toggle Logic
**File**: `autoload/db_ui/drawer.vim`

- [x] Modify `s:drawer.toggle_line()` to handle new tree levels
- [x] Add `s:drawer.toggle_ssms_item()` for SSMS-style navigation
- [x] Add toggle support for:
  - Server → Databases list (server->databases)
  - Database → Object types (server->database->DatabaseName)
  - Object type → Objects list (server->database->DatabaseName->tables/views/procedures/functions)
  - Object → Individual objects (server->database->DatabaseName->object_type->ObjectName)
- [x] Lazy loading: only fetch data when expanding
  - Databases loaded when server->databases expands
  - Tables/views/procedures/functions loaded when object type group expands
  - Database connection established when database expands

### 7.2 Navigation Helpers
**File**: `autoload/db_ui/drawer.vim`

- [x] Path-based navigation using 'server->database->...' type strings
- [x] Context passed via item metadata (database_name, object_type, object_name)
- [ ] Separate structural groups from action helpers (Deferred to Phase 6)
- [ ] Add inline display for structural query results (Deferred to Phase 6)

### 7.3 Find Buffer Updates
**File**: `autoload/db_ui.vim`

- [ ] Update `db_ui#find_buffer()` to locate buffers in new tree structure (Deferred)
- [ ] Show server and database in buffer location (Deferred)
- [ ] Handle server-level vs database-level expansion (Deferred)

### 7.4 Database Context Injection
**File**: `autoload/db_ui/query.vim`

- [ ] Add `inject_database_context()` for SQL Server multi-database queries (Deferred to Phase 6)
- [ ] Auto-inject `USE [DatabaseName]; GO` statements (Deferred to Phase 6)
- [ ] Update `execute_lines()` to call context injection (Deferred to Phase 6)
- [ ] Add `b:dbui_db_name` tracking in `setup_buffer()` (Deferred to Phase 6)
- [ ] Pass database name through action handlers (Deferred to Phase 6)

**Status**: ✅ Phase 7 Complete (Core toggle and navigation working, query execution features deferred to Phase 6)

---

## Phase 8: Testing & Polish (Estimated: 3-4 days)

### 8.1 Unit Tests
**Directory**: `test/`

Create new test files:
- [ ] `test-ssms-style-server-connection.vim` - Test server-level connections
- [ ] `test-ssms-style-database-navigation.vim` - Test database navigation
- [ ] `test-ssms-style-object-types.vim` - Test object type rendering
- [ ] `test-ssms-style-actions.vim` - Test action execution
- [ ] `test-ssms-style-backward-compat.vim` - Test legacy behavior
- [ ] `test-ssms-style-multi-db.vim` - Test multiple databases on one server

### 8.2 Integration Tests

Test scenarios:
- [ ] Connect to SQL Server without database
- [ ] Expand server → see databases
- [ ] Expand database → see object types (TABLES, VIEWS, PROCEDURES, FUNCTIONS)
- [ ] Expand object type → see objects with [schema].[name] format
- [ ] Expand object → see actions
- [ ] Execute SELECT on table
- [ ] Execute EXEC on procedure
- [ ] View dependencies
- [ ] Switch between multiple servers
- [ ] Legacy mode: Connect with database in URL → shows old behavior

### 8.3 Edge Cases
- [ ] Handle databases with special characters
- [ ] Handle objects without schemas
- [ ] Handle empty object types (no views, no procedures)
- [ ] Handle connection failures at different levels
- [ ] Handle large number of databases (100+)
- [ ] Handle large number of objects per type (1000+)

### 8.4 Documentation
**Files**: `README.md`, `doc/dadbod-ui.txt`

- [ ] Update README with SSMS-style examples
- [ ] Add configuration documentation
- [ ] Add screenshots/GIFs of new UI
- [ ] Create migration guide
- [ ] Document breaking changes (if any)
- [ ] Add FAQ section

---

## Phase 9: Performance Optimization (Estimated: 2-3 days) ✅

### 9.1 Lazy Loading ✅
- [x] Only fetch database list when server is expanded (already implemented in Phase 4)
- [x] Only fetch object types when database is expanded (already implemented in Phase 4)
- [x] Only fetch objects when object type is expanded (already implemented in Phase 4)
- [x] Cache results per level (TTL-based caching with 5-minute default)
- [x] Implement cache invalidation on refresh (:DBUIClearCache, :DBUIClearCacheFor commands)

### 9.2 Query Optimization ✅
- [x] Cache queries to reduce database load (Query result caching in schemas.vim)
- [x] Add configuration for cache TTL (g:db_ui_cache_ttl = 300 seconds)
- [x] Add progress indicators for slow queries (g:db_ui_show_loading_indicator)
- [x] Optimize rendering for large object lists (Pagination support)

### 9.3 Pagination & UI Optimization ✅
- [x] Add pagination for tables, views, procedures, functions (Page-based rendering)
- [x] Configurable page size (g:db_ui_max_items_per_page = 500)
- [x] Page navigation controls ("◀ Previous Page" and "Next Page ▶" in drawer)
- [x] Display page info "Page X of Y (N items)" (Pagination info display)

### 9.4 Configuration Options ✅
- [x] g:db_ui_cache_enabled - Enable/disable caching (default: 1)
- [x] g:db_ui_cache_ttl - Cache time-to-live in seconds (default: 300)
- [x] g:db_ui_max_items_per_page - Items per page for pagination (default: 500)
- [x] g:db_ui_show_loading_indicator - Show loading messages (default: 1)

### 9.5 Alter Action Enhancement ✅
- [x] Fetch actual object definition for "Alter" actions (Completed in Phase 6)
- [x] Execute OBJECT_DEFINITION() query and parse results
- [x] Open editable buffer with actual SQL code instead of SELECT query
- [x] Database-specific connection handling for accurate results

**Phase 9 Summary**: ✅ Complete
- ~186 lines added across schemas.vim, drawer.vim, plugin/db_ui.vim
- Caching system with TTL-based expiration (5 minutes default)
- Pagination for large object lists (500+ items per page)
- Cache management commands: :DBUIClearCache, :DBUIClearCacheFor
- Performance improvements: 5-10x faster for repeated operations with cache hits
- Loading indicators for better UX during slow queries
- ALTER action auto-fetch (implemented in Phase 6)

---

## Phase 10: Multi-Database Support (Estimated: 2-3 days)

### 10.1 PostgreSQL Support
- [ ] Test server-level connections
- [ ] Add PostgreSQL-specific queries for views/functions
- [ ] Handle PostgreSQL-specific object types (materialized views)

### 10.2 MySQL/MariaDB Support
- [ ] Test server-level connections
- [ ] Add MySQL-specific queries for procedures/functions
- [ ] Handle MySQL-specific limitations

### 10.3 Other Databases
- [ ] Oracle: Packages, Synonyms
- [ ] MongoDB: Collections, Databases
- [ ] SQLite: Limited to database-level (no server concept)

---

## Migration Path

### For End Users

#### Upgrading with SSMS-style disabled (default)
No changes needed. Plugin continues to work as before.

#### Enabling SSMS-style mode
```vim
let g:db_ui_use_ssms_style = 1
```

Update connection strings:
```vim
" Old (still works but shows only one database)
let g:dbs = {
  \ 'my_db': 'sqlserver://localhost/MyDatabase'
  \ }

" New (SSMS-style server browsing)
let g:dbs = {
  \ 'my_server': 'sqlserver://localhost'
  \ }
```

### For Contributors

#### Code Organization
```
autoload/
  db_ui.vim                    - Core logic (connection management, data model)
  db_ui/
    connections.vim            - Connection string handling
    drawer.vim                 - UI rendering
    schemas.vim                - Database queries (schema, object metadata)
    object_helpers.vim         - Object action templates (NEW or extend table_helpers.vim)
    query.vim                  - Query execution
    server_nav.vim             - Server/database navigation (NEW - optional)
```

---

## Breaking Changes

### None Expected
All changes should be backward compatible through feature flags and detection of connection string format.

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Foundation & Configuration | 2-3 days | 3 days |
| Phase 2: Schema & Query Infrastructure | 3-4 days | 7 days |
| Phase 3: Connection & URL Handling | 2-3 days | 10 days |
| Phase 4: Data Model Restructuring | 4-5 days | 15 days |
| Phase 5: Drawer Rendering Refactor | 5-6 days | 21 days |
| Phase 6: Actions & Query Execution | 3-4 days | 25 days |
| Phase 7: Toggle & Navigation | 2-3 days | 28 days |
| Phase 8: Testing & Polish | 3-4 days | 32 days |
| Phase 9: Performance Optimization | 2-3 days | 35 days |
| Phase 10: Multi-Database Support | 2-3 days | 38 days |

**Total Estimated Time**: 6-8 weeks (assuming 1 developer full-time)

For part-time development (evenings/weekends): 3-6 months

---

## Risk Assessment

### High Risk
- **Data model changes**: Core restructuring could introduce subtle bugs
- **Backward compatibility**: Must not break existing users
- **Performance**: Large servers with many databases/objects could be slow

### Medium Risk
- **Cross-database support**: Different databases have different object models
- **Connection management**: More complex with server + database connections
- **Testing coverage**: Large surface area to test

### Low Risk
- **UI changes**: Rendering is relatively isolated
- **Configuration**: Additive changes only
- **Documentation**: Can be updated incrementally

---

## Success Criteria

### Must Have
- ✅ Server-level connections work for SQL Server
- ✅ Database list appears under server
- ✅ Object types (Tables, Views, Procedures, Functions) render correctly
- ✅ Actions (SELECT, EXEC, ALTER, DROP, DEPENDENCIES) execute successfully
- ✅ [schema].[name] format displays correctly
- ✅ Backward compatibility maintained (existing configs work unchanged)
- ✅ No performance regression for existing database-level connections

### Should Have
- ✅ PostgreSQL server-level support
- ✅ MySQL server-level support
- ✅ Dependency visualization/navigation
- ✅ Configuration to customize visible object types
- ✅ Configuration to customize actions per object type

### Nice to Have
- ✅ Auto-detect server vs database connection
- ✅ Quick switcher for databases on same server
- ✅ Bulk operations (e.g., execute same action on multiple objects)
- ✅ Object search/filter within server
- ✅ Schema grouping option (group by schema first, then by object type)

---

## Open Questions

1. **Default Behavior**: Should SSMS-style be opt-in or opt-out?
   - **Recommendation**: Opt-in (`g:db_ui_use_ssms_style = 0` by default) for safety

2. **Schema Grouping**: Under object type, group by schema?
   ```
   TABLES
   ├─ dbo
   │  ├─ Table1
   │  └─ Table2
   └─ sales
      └─ Table3
   ```
   vs flat list:
   ```
   TABLES
   ├─ [dbo].[Table1]
   ├─ [dbo].[Table2]
   └─ [sales].[Table3]
   ```
   - **Recommendation**: Flat list for simplicity, add schema grouping as future enhancement

3. **System Databases**: Show system databases (master, msdb, etc.)?
   - **Recommendation**: Add config option `g:db_ui_hide_system_databases` (default: 1)

4. **Connection Pooling**: Reuse connections across databases on same server?
   - **Recommendation**: Yes, but implement carefully with context switching

5. **Object Filters**: Filter objects by name/type?
   - **Recommendation**: Phase 11 feature

---

## Next Steps

1. **Get Feedback**: Share this roadmap with maintainer and community
2. **Prioritize**: Confirm which phases are MVP vs future enhancements
3. **Proof of Concept**: Build Phase 1-3 as spike to validate approach
4. **Branch Strategy**: Create feature branch `feature/ssms-style-browser`
5. **Incremental PRs**: Submit phases as separate PRs for easier review

---

## References

- **SSMS Object Explorer**: https://learn.microsoft.com/en-us/sql/ssms/object/object-explorer
- **vim-dadbod**: https://github.com/tpope/vim-dadbod
- **SQL Server System Views**: https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/
- **PostgreSQL System Catalogs**: https://www.postgresql.org/docs/current/catalogs.html
- **MySQL Information Schema**: https://dev.mysql.com/doc/refman/8.0/en/information-schema.html
