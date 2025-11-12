# SSNS Architecture - Class-Based Design

## Overview

SSNS uses a **hierarchical class structure** to represent database objects. This single tree serves as the source of truth for both:
1. **UI Rendering** (tree display in drawer)
2. **IntelliSense** (completion lookup)

## Core Principle

**One tree, two consumers:**
```
┌─────────────────────────────────┐
│   ServerClass Tree (Cache)      │
│   server → db → schema → table  │
└────────────┬────────────────────┘
             │
      ┌──────┴───────┐
      ▼              ▼
  ┌────────┐    ┌─────────────┐
  │   UI   │    │ IntelliSense│
  │ Drawer │    │  (Phase 2)  │
  └────────┘    └─────────────┘
```

No data duplication. UI reads display properties, IntelliSense reads object metadata.

---

## Class Hierarchy

### Base Class (Abstract)

```lua
---@class BaseDbObject
---@field name string Object name
---@field parent BaseDbObject? Parent in hierarchy
---@field is_loaded boolean Has data been fetched?
---@field last_updated number Timestamp of last load
---@field metadata table Extensible metadata storage
---@field ui_state UiState UI-specific display state
local BaseDbObject = {}

---Get full hierarchical path
---@return string Example: "SQLEXPRESS.vim_dadbod_test.dbo.Employees"
function BaseDbObject:get_full_path() end

---Refresh object data from database
---@param force boolean? Force reload even if not stale
function BaseDbObject:refresh(force) end

---Check if object data is stale
---@param ttl number Time-to-live in seconds
---@return boolean
function BaseDbObject:is_stale(ttl) end

---Iterator for children
---@return function iterator
function BaseDbObject:get_children() end
```

### UI State (Separate from Data)

```lua
---@class UiState
---@field expanded boolean Is node expanded in tree?
---@field visible boolean Is node currently visible?
---@field icon string Icon character/emoji
---@field highlight_group string Highlight group name
---@field line_number number? Cached line number in buffer
local UiState = {
  expanded = false,
  visible = true,
  icon = "",
  highlight_group = "Normal",
  line_number = nil,
}
```

### Server Class

```lua
---@class ServerClass : BaseDbObject
---@field connection_string string Connection URL
---@field connection any Active database connection
---@field connection_state ConnectionState
---@field error_message string? Error if connection failed
---@field db_list DbClass[] List of databases
---@field server_properties ServerProperties Server metadata
local ServerClass = {}

---@enum ConnectionState
local ConnectionState = {
  DISCONNECTED = "disconnected",
  CONNECTING = "connecting",
  CONNECTED = "connected",
  ERROR = "error"
}

---Connect to server
---@return boolean success
---@return string? error_message
function ServerClass:connect() end

---Disconnect from server
function ServerClass:disconnect() end

---Test connection without fully connecting
---@return boolean is_valid
function ServerClass:test_connection() end

---Get currently active database
---@return DbClass?
function ServerClass:get_active_database() end

---Load list of databases
---@return DbClass[]
function ServerClass:load_databases() end
```

### Database Class

```lua
---@class DbClass : BaseDbObject
---@field db_name string Database name
---@field schema_list SchemaClass[] Schemas in this DB
---@field synonym_list SynonymClass[] Database-level synonyms
---@field parent ServerClass Parent server
local DbClass = {}

---Load schemas for this database
---@return SchemaClass[]
function DbClass:load_schemas() end

---Load synonyms for this database
---@return SynonymClass[]
function DbClass:load_synonyms() end

---Find schema by name (case-insensitive)
---@param schema_name string
---@return SchemaClass?
function DbClass:find_schema(schema_name) end

---Get default schema (usually 'dbo' for SQL Server)
---@return string
function DbClass:get_default_schema() end
```

### Schema Class

```lua
---@class SchemaClass : BaseDbObject
---@field schema_name string Schema name (e.g., "dbo", "hr")
---@field table_list TableClass[] Tables in schema
---@field view_list ViewClass[] Views in schema
---@field procedure_list ProcedureClass[] Stored procedures
---@field function_list FunctionClass[] User-defined functions
---@field parent DbClass Parent database
local SchemaClass = {}

---Load all objects in schema
---@param object_types string[]? Filter: {"tables", "views", "procedures"}
function SchemaClass:load_objects(object_types) end

---Load tables in this schema
---@return TableClass[]
function SchemaClass:load_tables() end

---Load views in this schema
---@return ViewClass[]
function SchemaClass:load_views() end

---Load procedures in this schema
---@return ProcedureClass[]
function SchemaClass:load_procedures() end

---Load functions in this schema
---@return FunctionClass[]
function SchemaClass:load_functions() end

---Find table by name
---@param table_name string
---@return TableClass?
function SchemaClass:find_table(table_name) end

---Get all objects of a type
---@param type string "table"|"view"|"procedure"|"function"
---@return BaseDbObject[]
function SchemaClass:get_objects_by_type(type) end
```

### Table Class

```lua
---@class TableClass : BaseDbObject
---@field table_name string Table name
---@field column_list ColumnClass[]? Lazy-loaded columns
---@field index_list IndexClass[]? Lazy-loaded indexes
---@field primary_key PrimaryKeyClass? Primary key constraint
---@field foreign_keys ForeignKeyClass[] Foreign key constraints
---@field check_constraints CheckConstraintClass[] Check constraints
---@field columns_loaded boolean Have columns been loaded?
---@field indexes_loaded boolean Have indexes been loaded?
---@field row_count number? Cached row count
---@field parent SchemaClass Parent schema
local TableClass = {}

---Get columns (lazy load if needed)
---@return ColumnClass[]
function TableClass:get_columns() end

---Get indexes (lazy load if needed)
---@return IndexClass[]
function TableClass:get_indexes() end

---Load all table metadata (columns, indexes, keys, constraints)
function TableClass:load_all() end

---Find column by name
---@param column_name string
---@return ColumnClass?
function TableClass:find_column(column_name) end

---Get primary key columns
---@return ColumnClass[]
function TableClass:get_primary_key_columns() end

---Get foreign keys targeting this table
---@return ForeignKeyClass[]
function TableClass:get_incoming_foreign_keys() end

---Generate SELECT statement
---@param top number? LIMIT clause
---@return string SQL query
function TableClass:generate_select(top) end

---Generate INSERT template
---@return string SQL template
function TableClass:generate_insert() end

---Get estimated row count (fast, cached)
---@return number
function TableClass:get_row_count() end
```

### Column Class

```lua
---@class ColumnClass : BaseDbObject
---@field column_name string Column name
---@field data_type string Base data type (e.g., "nvarchar", "int")
---@field max_length number? Max length for string types
---@field precision number? Precision for numeric types
---@field scale number? Scale for numeric types
---@field is_nullable boolean Can be NULL?
---@field is_identity boolean Is IDENTITY column?
---@field is_computed boolean Is computed column?
---@field default_value string? Default constraint value
---@field ordinal_position number Position in table
---@field parent TableClass Parent table
local ColumnClass = {}

---Get full type string (e.g., "nvarchar(50)", "decimal(10,2)")
---@return string
function ColumnClass:get_full_type() end

---Check if this column is part of primary key
---@return boolean
function ColumnClass:is_primary_key() end

---Check if this column is part of a foreign key
---@return boolean
function ColumnClass:is_foreign_key() end

---Get foreign key target if this is an FK column
---@return TableClass?, ColumnClass?
function ColumnClass:get_foreign_key_target() end

---Get suggested completion text
---@return string
function ColumnClass:get_completion_label() end
```

### View Class

```lua
---@class ViewClass : BaseDbObject
---@field view_name string View name
---@field column_list ColumnClass[]? Lazy-loaded columns
---@field definition string? View definition (CREATE VIEW ...)
---@field is_indexed boolean Is indexed view?
---@field parent SchemaClass Parent schema
local ViewClass = {}

---Get columns (lazy load if needed)
---@return ColumnClass[]
function ViewClass:get_columns() end

---Get view definition
---@return string SQL definition
function ViewClass:get_definition() end

---Generate SELECT from view
---@param top number?
---@return string
function ViewClass:generate_select(top) end
```

### Procedure Class

```lua
---@class ProcedureClass : BaseDbObject
---@field procedure_name string Procedure name
---@field parameter_list ParameterClass[]? Lazy-loaded parameters
---@field definition string? Procedure definition
---@field parent SchemaClass Parent schema
local ProcedureClass = {}

---Get parameters (lazy load if needed)
---@return ParameterClass[]
function ProcedureClass:get_parameters() end

---Get procedure definition
---@return string
function ProcedureClass:get_definition() end

---Generate EXEC statement template
---@return string
function ProcedureClass:generate_exec() end
```

### Function Class

```lua
---@class FunctionClass : BaseDbObject
---@field function_name string Function name
---@field parameter_list ParameterClass[]? Parameters
---@field return_type string Return data type
---@field definition string? Function definition
---@field function_type string "scalar"|"table"|"inline_table"
---@field parent SchemaClass Parent schema
local FunctionClass = {}

---Get parameters
---@return ParameterClass[]
function FunctionClass:get_parameters() end

---Get definition
---@return string
function FunctionClass:get_definition() end

---Generate SELECT using function
---@return string
function FunctionClass:generate_select() end
```

### Parameter Class

```lua
---@class ParameterClass : BaseDbObject
---@field parameter_name string Parameter name (with @)
---@field data_type string Data type
---@field max_length number?
---@field is_output boolean Is OUTPUT parameter?
---@field default_value string? Default value
---@field ordinal_position number Position in parameter list
---@field parent ProcedureClass|FunctionClass Parent procedure/function
local ParameterClass = {}

---Get full type string
---@return string
function ParameterClass:get_full_type() end

---Get parameter direction
---@return string "IN"|"OUT"|"INOUT"
function ParameterClass:get_direction() end
```

### Synonym Class

```lua
---@class SynonymClass : BaseDbObject
---@field synonym_name string Synonym name
---@field target_string string Raw target (e.g., "dbo.Employees")
---@field target_database string? Target database if cross-DB
---@field target_schema string Target schema
---@field target_object string Target object name
---@field resolved_target TableClass|ViewClass? Resolved reference
---@field parent DbClass Parent database
local SynonymClass = {}

---Resolve synonym to actual object
---@return TableClass|ViewClass?
function SynonymClass:resolve() end

---Get columns from target object
---@return ColumnClass[]
function SynonymClass:get_columns() end

---Get target full path
---@return string
function SynonymClass:get_target_path() end
```

### Index Class

```lua
---@class IndexClass : BaseDbObject
---@field index_name string Index name
---@field is_unique boolean Unique constraint?
---@field is_primary_key boolean Is PK index?
---@field is_clustered boolean Clustered vs nonclustered
---@field column_list ColumnClass[] Columns in index
---@field included_columns ColumnClass[]? INCLUDE columns
---@field filter_definition string? Filtered index WHERE clause
---@field parent TableClass Parent table
local IndexClass = {}

---Get index definition
---@return string
function IndexClass:get_definition() end

---Check if index covers specific columns
---@param columns string[]
---@return boolean
function IndexClass:covers_columns(columns) end
```

### Constraint Classes

```lua
---@class ConstraintClass : BaseDbObject
---@field constraint_name string
---@field constraint_type string "PK"|"FK"|"CHECK"|"UNIQUE"|"DEFAULT"
local ConstraintClass = {}

---@class PrimaryKeyClass : ConstraintClass
---@field column_list ColumnClass[] Columns in PK
local PrimaryKeyClass = {}

---@class ForeignKeyClass : ConstraintClass
---@field source_columns ColumnClass[] Source columns
---@field target_table TableClass Target table reference
---@field target_columns ColumnClass[] Target columns
---@field on_delete string "CASCADE"|"SET NULL"|"NO ACTION"
---@field on_update string
local ForeignKeyClass = {}

---@class CheckConstraintClass : ConstraintClass
---@field check_expression string CHECK expression
local CheckConstraintClass = {}
```

### Server Properties Class

```lua
---@class ServerProperties
---@field version string SQL Server version (e.g., "15.0.2000.5")
---@field edition string Edition (e.g., "Express", "Standard")
---@field product_level string Service pack level
---@field collation string Default collation
---@field max_connections number
local ServerProperties = {}

---Check if server supports feature
---@param feature string Feature name
---@return boolean
function ServerProperties:supports_feature(feature) end
```

---

## Factory Pattern for Object Creation

```lua
-- lua/ssns/factory.lua
local Factory = {}

---Create server instance
---@param connection_string string
---@return ServerClass
function Factory.create_server(connection_string)
  local server = ServerClass.new({
    name = extract_server_name(connection_string),
    connection_string = connection_string,
    connection_state = ConnectionState.DISCONNECTED,
  })
  return server
end

---Create database from query result
---@param server ServerClass
---@param row table Query result row
---@return DbClass
function Factory.create_database(server, row)
  return DbClass.new({
    name = row.database_name,
    parent = server,
  })
end

-- Similar factories for all object types
```

---

## Navigation Methods

Every object can navigate up and down:

```lua
-- Navigate up
local column = get_column_somehow()
local table = column.parent
local schema = table.parent
local database = schema.parent
local server = database.parent

-- Navigate down
local server = get_server()
local databases = server:get_children()  -- Iterator
for db in databases do
  for schema in db:get_children() do
    for table in schema:get_tables() do
      print(table:get_full_path())
    end
  end
end

-- Shorthand path resolution
local column = server
  :find_database("vim_dadbod_test")
  :find_schema("dbo")
  :find_table("Employees")
  :find_column("EmployeeID")
```

---

## File Organization

```
lua/ssns/
├── init.lua                    # Plugin entry point
├── config.lua                  # User configuration
├── classes/
│   ├── base.lua                # BaseDbObject
│   ├── server.lua              # ServerClass
│   ├── database.lua            # DbClass
│   ├── schema.lua              # SchemaClass
│   ├── table.lua               # TableClass
│   ├── view.lua                # ViewClass
│   ├── procedure.lua           # ProcedureClass
│   ├── function.lua            # FunctionClass
│   ├── synonym.lua             # SynonymClass
│   ├── column.lua              # ColumnClass
│   ├── index.lua               # IndexClass
│   ├── constraint.lua          # Constraint classes
│   └── parameter.lua           # ParameterClass
├── factory.lua                 # Object creation factory
├── cache.lua                   # Global cache manager
├── connection.lua              # Connection management
├── ui/
│   ├── tree.lua                # Tree renderer
│   ├── buffer.lua              # Buffer management
│   └── highlights.lua          # Syntax highlighting
└── adapters/
    └── sqlserver.lua           # SQL Server queries
```

---

## Benefits of This Architecture

1. **Type Safety**: LuaLS annotations provide IDE autocomplete
2. **Single Source of Truth**: One tree for UI and IntelliSense
3. **Easy Navigation**: Parent/child references
4. **Lazy Loading**: Load columns/indexes only when needed
5. **Consistent API**: All classes inherit from BaseDbObject
6. **Testable**: Each class can be unit tested
7. **Extensible**: Easy to add new object types
8. **Memory Efficient**: Lazy loading + TTL expiration

---

## Next Steps

**Phase 1**: Implement class hierarchy
- [ ] Create base classes with type annotations
- [ ] Implement factory pattern
- [ ] Add navigation methods
- [ ] Write unit tests

**Phase 2**: UI Integration
- [ ] Tree renderer reading from classes
- [ ] UI state management
- [ ] Expand/collapse with lazy loading

**Phase 3**: IntelliSense (Later)
- [ ] Context detection
- [ ] Class-based completion lookup
- [ ] Fuzzy matching on object names
