# SSNS Multi-Database Architecture

## Overview

SSNS uses a **universal class hierarchy** that works for ALL databases, with **adapter-specific implementations** only for queries and features.

## Design Principle

**Write once, support many databases:**

```
Universal Classes (99%)     Adapters (1%)
    │                           │
    │                           │
    ▼                           ▼
TableClass.get_columns()  →  SqlServerAdapter.get_columns_query()
                         →  PostgresAdapter.get_columns_query()
                         →  MySqlAdapter.get_columns_query()
                         →  SqliteAdapter.get_columns_query()
```

---

## Universal Class Hierarchy

These classes work for **ALL databases** without modification:

### BaseDbObject (Abstract)
```lua
---@class BaseDbObject
---@field name string
---@field parent BaseDbObject?
---@field children BaseDbObject[]
---@field is_loaded boolean
---@field last_updated number
---@field ui_state UiState
local BaseDbObject = {}

function BaseDbObject:get_adapter()
  -- Walk up tree to server, get adapter
  local server = self:get_server()
  return server.adapter
end

function BaseDbObject:get_server()
  local node = self
  while node.parent do
    node = node.parent
  end
  return node
end
```

### ServerClass
```lua
---@class ServerClass : BaseDbObject
---@field connection_string string
---@field db_type DbType Database type
---@field adapter BaseAdapter Database-specific adapter
---@field connection any
---@field connection_state ConnectionState
---@field db_list DbClass[]
local ServerClass = {}

---@enum DbType
local DbType = {
  SQLSERVER = "sqlserver",
  POSTGRES = "postgres",
  MYSQL = "mysql",
  SQLITE = "sqlite",
  BIGQUERY = "bigquery",
  ORACLE = "oracle",
  CLICKHOUSE = "clickhouse",
}

function ServerClass:connect()
  -- Use adapter for connection
  local success, conn = self.adapter:connect(self.connection_string)
  if success then
    self.connection = conn
    self.connection_state = ConnectionState.CONNECTED
  end
  return success
end

function ServerClass:load_databases()
  -- Adapter provides query
  local query = self.adapter:get_databases_query()
  local results = self.adapter:execute(self.connection, query)

  self.db_list = {}
  for _, row in ipairs(results) do
    local db = self.adapter:create_database(self, row)
    table.insert(self.db_list, db)
  end

  return self.db_list
end
```

### DbClass
```lua
---@class DbClass : BaseDbObject
---@field db_name string
---@field schema_list SchemaClass[]
---@field supports_schemas boolean
local DbClass = {}

function DbClass:load_schemas()
  local adapter = self:get_adapter()

  -- Check if database type supports schemas
  if not adapter.features.schemas then
    -- Create a default "schema" for databases without schema support
    local default_schema = SchemaClass.new({
      name = "default",
      parent = self
    })
    self.schema_list = { default_schema }
    return self.schema_list
  end

  -- Database supports schemas, query for them
  local query = adapter:get_schemas_query(self.db_name)
  local results = adapter:execute(self:get_server().connection, query)

  self.schema_list = {}
  for _, row in ipairs(results) do
    local schema = adapter:create_schema(self, row)
    table.insert(self.schema_list, schema)
  end

  return self.schema_list
end
```

### SchemaClass
```lua
---@class SchemaClass : BaseDbObject
---@field schema_name string
---@field table_list TableClass[]
---@field view_list ViewClass[]
---@field procedure_list ProcedureClass[]
---@field function_list FunctionClass[]
---@field synonym_list SynonymClass[]?
---@field sequence_list SequenceClass[]?
local SchemaClass = {}

function SchemaClass:load_objects(object_types)
  local adapter = self:get_adapter()

  -- Always load tables and views
  if not object_types or vim.tbl_contains(object_types, "tables") then
    self:load_tables()
  end

  if not object_types or vim.tbl_contains(object_types, "views") then
    self:load_views()
  end

  -- Conditionally load based on adapter features
  if adapter.features.procedures then
    if not object_types or vim.tbl_contains(object_types, "procedures") then
      self:load_procedures()
    end
  end

  if adapter.features.functions then
    if not object_types or vim.tbl_contains(object_types, "functions") then
      self:load_functions()
    end
  end

  if adapter.features.synonyms then
    if not object_types or vim.tbl_contains(object_types, "synonyms") then
      self:load_synonyms()
    end
  end

  if adapter.features.sequences then
    if not object_types or vim.tbl_contains(object_types, "sequences") then
      self:load_sequences()
    end
  end
end

function SchemaClass:load_tables()
  local adapter = self:get_adapter()
  local query = adapter:get_tables_query(self.parent.db_name, self.schema_name)
  local results = adapter:execute(self:get_server().connection, query)

  self.table_list = {}
  for _, row in ipairs(results) do
    local table = adapter:create_table(self, row)
    table.insert(self.table_list, table)
  end

  return self.table_list
end

-- Similar for load_views, load_procedures, etc.
```

### TableClass (Universal!)
```lua
---@class TableClass : BaseDbObject
---@field table_name string
---@field column_list ColumnClass[]?
---@field index_list IndexClass[]?
---@field primary_key PrimaryKeyClass?
---@field foreign_keys ForeignKeyClass[]
local TableClass = {}

function TableClass:get_columns()
  if self.columns_loaded then
    return self.column_list
  end

  local adapter = self:get_adapter()
  local db = self.parent.parent.db_name
  local schema = self.parent.schema_name

  local query = adapter:get_columns_query(db, schema, self.table_name)
  local results = adapter:execute(self:get_server().connection, query)

  self.column_list = {}
  for _, row in ipairs(results) do
    local column = adapter:create_column(self, row)
    table.insert(self.column_list, column)
  end

  self.columns_loaded = true
  return self.column_list
end

-- Same pattern for indexes, constraints, etc.
```

---

## Adapter Pattern

### BaseAdapter (Interface)

```lua
---@class BaseAdapter
---@field db_type string
---@field features AdapterFeatures
local BaseAdapter = {}

---@class AdapterFeatures
---@field schemas boolean
---@field synonyms boolean
---@field procedures boolean
---@field functions boolean
---@field sequences boolean
---@field indexes boolean
---@field foreign_keys boolean
local AdapterFeatures = {}

-- Connection
function BaseAdapter:connect(connection_string) end
function BaseAdapter:disconnect(connection) end
function BaseAdapter:test_connection(connection_string) end

-- Metadata queries (return SQL strings)
function BaseAdapter:get_databases_query() end
function BaseAdapter:get_schemas_query(db_name) end
function BaseAdapter:get_tables_query(db_name, schema_name) end
function BaseAdapter:get_views_query(db_name, schema_name) end
function BaseAdapter:get_procedures_query(db_name, schema_name) end
function BaseAdapter:get_functions_query(db_name, schema_name) end
function BaseAdapter:get_columns_query(db_name, schema_name, table_name) end
function BaseAdapter:get_indexes_query(db_name, schema_name, table_name) end
function BaseAdapter:get_foreign_keys_query(db_name, schema_name, table_name) end

-- Optional (only if supported)
function BaseAdapter:get_synonyms_query(db_name) end
function BaseAdapter:get_sequences_query(db_name, schema_name) end

-- Result parsing (convert query results to class instances)
function BaseAdapter:create_database(server, row) end
function BaseAdapter:create_schema(database, row) end
function BaseAdapter:create_table(schema, row) end
function BaseAdapter:create_column(table, row) end

-- Query execution
function BaseAdapter:execute(connection, query) end

-- Data type mapping
function BaseAdapter:map_data_type(native_type) end
```

---

## Database-Specific Adapters

### SQL Server Adapter

```lua
---@class SqlServerAdapter : BaseAdapter
local SqlServerAdapter = {}

SqlServerAdapter.db_type = "sqlserver"
SqlServerAdapter.features = {
  schemas = true,
  synonyms = true,
  procedures = true,
  functions = true,
  sequences = false,  -- Uses IDENTITY instead
  indexes = true,
  foreign_keys = true,
}

function SqlServerAdapter:get_databases_query()
  return [[
    SELECT name as database_name
    FROM sys.databases
    WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
      AND state = 0  -- ONLINE
    ORDER BY name
  ]]
end

function SqlServerAdapter:get_schemas_query(db_name)
  return string.format([[
    USE [%s];
    SELECT schema_name
    FROM INFORMATION_SCHEMA.SCHEMATA
    WHERE schema_name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest')
    ORDER BY schema_name
  ]], db_name)
end

function SqlServerAdapter:get_tables_query(db_name, schema_name)
  return string.format([[
    USE [%s];
    SET NOCOUNT ON;
    SELECT table_schema, table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE'
      AND table_schema = '%s'
      AND table_name NOT LIKE 'spt_%%'
    ORDER BY table_name
  ]], db_name, schema_name)
end

function SqlServerAdapter:get_columns_query(db_name, schema_name, table_name)
  return string.format([[
    USE [%s];
    SET NOCOUNT ON;
    SELECT
      c.column_name,
      c.data_type,
      c.character_maximum_length,
      c.numeric_precision,
      c.numeric_scale,
      CASE WHEN c.is_nullable = 'YES' THEN 1 ELSE 0 END as is_nullable,
      c.column_default,
      COLUMNPROPERTY(OBJECT_ID('[%s].[%s]'), c.column_name, 'IsIdentity') as is_identity,
      COLUMNPROPERTY(OBJECT_ID('[%s].[%s]'), c.column_name, 'IsComputed') as is_computed,
      c.ordinal_position
    FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.table_schema = '%s'
      AND c.table_name = '%s'
    ORDER BY c.ordinal_position
  ]], db_name, schema_name, table_name, schema_name, table_name, schema_name, table_name)
end

function SqlServerAdapter:get_synonyms_query(db_name)
  return string.format([[
    USE [%s];
    SELECT
      SCHEMA_NAME(schema_id) as schema_name,
      name as synonym_name,
      base_object_name as target_object
    FROM sys.synonyms
    ORDER BY name
  ]], db_name)
end

-- SQL Server specific: map native types
function SqlServerAdapter:map_data_type(native_type)
  local type_map = {
    ["int"] = "integer",
    ["nvarchar"] = "string",
    ["varchar"] = "string",
    ["datetime"] = "datetime",
    ["bit"] = "boolean",
  }
  return type_map[native_type] or native_type
end
```

### PostgreSQL Adapter

```lua
---@class PostgresAdapter : BaseAdapter
local PostgresAdapter = {}

PostgresAdapter.db_type = "postgres"
PostgresAdapter.features = {
  schemas = true,
  synonyms = false,  -- PostgreSQL doesn't have synonyms
  procedures = true,
  functions = true,
  sequences = true,  -- PostgreSQL has sequences
  indexes = true,
  foreign_keys = true,
}

function PostgresAdapter:get_databases_query()
  return [[
    SELECT datname as database_name
    FROM pg_database
    WHERE datistemplate = false
      AND datname NOT IN ('postgres', 'template0', 'template1')
    ORDER BY datname
  ]]
end

function PostgresAdapter:get_schemas_query(db_name)
  -- PostgreSQL: schemas are per-database
  return [[
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    ORDER BY schema_name
  ]]
end

function PostgresAdapter:get_tables_query(db_name, schema_name)
  return string.format([[
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema = '%s'
    ORDER BY table_name
  ]], schema_name)
end

function PostgresAdapter:get_sequences_query(db_name, schema_name)
  return string.format([[
    SELECT sequence_schema, sequence_name,
           increment, minimum_value, maximum_value
    FROM information_schema.sequences
    WHERE sequence_schema = '%s'
    ORDER BY sequence_name
  ]], schema_name)
end

function PostgresAdapter:map_data_type(native_type)
  local type_map = {
    ["integer"] = "integer",
    ["bigint"] = "integer",
    ["character varying"] = "string",
    ["text"] = "string",
    ["timestamp without time zone"] = "datetime",
    ["boolean"] = "boolean",
  }
  return type_map[native_type] or native_type
end
```

### MySQL Adapter

```lua
---@class MySqlAdapter : BaseAdapter
local MySqlAdapter = {}

MySqlAdapter.db_type = "mysql"
MySqlAdapter.features = {
  schemas = false,  -- MySQL calls them "databases"
  synonyms = false,
  procedures = true,
  functions = true,
  sequences = false,  -- Uses AUTO_INCREMENT
  indexes = true,
  foreign_keys = true,
}

function MySqlAdapter:get_databases_query()
  return [[
    SELECT schema_name as database_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
    ORDER BY schema_name
  ]]
end

-- MySQL doesn't have schemas, so return empty
function MySqlAdapter:get_schemas_query(db_name)
  return nil  -- Will use default schema
end

function MySqlAdapter:get_tables_query(db_name, schema_name)
  return string.format([[
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema = '%s'
    ORDER BY table_name
  ]], db_name)  -- Note: db_name, not schema_name!
end
```

### SQLite Adapter

```lua
---@class SqliteAdapter : BaseAdapter
local SqliteAdapter = {}

SqliteAdapter.db_type = "sqlite"
SqliteAdapter.features = {
  schemas = false,  -- Single namespace
  synonyms = false,
  procedures = false,  -- No stored procedures
  functions = false,
  sequences = false,
  indexes = true,
  foreign_keys = true,  -- But often disabled
}

function SqliteAdapter:get_databases_query()
  -- SQLite: file-based, single "database"
  return nil
end

function SqliteAdapter:get_schemas_query(db_name)
  return nil  -- No schemas
end

function SqliteAdapter:get_tables_query(db_name, schema_name)
  return [[
    SELECT name as table_name
    FROM sqlite_master
    WHERE type = 'table'
      AND name NOT LIKE 'sqlite_%'
    ORDER BY name
  ]]
end

function SqliteAdapter:get_columns_query(db_name, schema_name, table_name)
  return string.format([[
    PRAGMA table_info(%s)
  ]], table_name)
end

-- SQLite result parsing is different
function SqliteAdapter:create_column(table, row)
  -- PRAGMA returns: cid, name, type, notnull, dflt_value, pk
  return ColumnClass.new({
    name = row.name,
    parent = table,
    data_type = row.type,
    is_nullable = row.notnull == 0,
    default_value = row.dflt_value,
    is_identity = row.pk == 1,  -- AUTOINCREMENT
    ordinal_position = row.cid,
  })
end
```

---

## Adapter Factory

```lua
-- lua/ssns/adapters/factory.lua
local AdapterFactory = {}

local adapters = {
  sqlserver = require('ssns.adapters.sqlserver'),
  postgres = require('ssns.adapters.postgres'),
  mysql = require('ssns.adapters.mysql'),
  sqlite = require('ssns.adapters.sqlite'),
  bigquery = require('ssns.adapters.bigquery'),
}

---Create adapter from connection string
---@param connection_string string
---@return BaseAdapter
function AdapterFactory.create(connection_string)
  local db_type = connection_string:match("^(%w+)://")

  if not db_type then
    error("Invalid connection string: " .. connection_string)
  end

  local adapter_class = adapters[db_type]
  if not adapter_class then
    error("Unsupported database type: " .. db_type)
  end

  return adapter_class.new()
end

return AdapterFactory
```

---

## Connection String Formats

```lua
-- SQL Server
"sqlserver://localhost/vim_dadbod_test"
"sqlserver://user:pass@server\\SQLEXPRESS/database"

-- PostgreSQL
"postgres://localhost:5432/mydb"
"postgres://user:pass@localhost/mydb"

-- MySQL
"mysql://localhost:3306/mydb"
"mysql://root:password@localhost/mydb"

-- SQLite
"sqlite:///path/to/database.db"
"sqlite://./local.db"

-- BigQuery
"bigquery://project-id/dataset"
```

---

## UI Rendering (Database-Agnostic!)

```lua
-- lua/ssns/ui/tree.lua
function TreeRenderer:render_schema(schema)
  local lines = {}
  local adapter = schema:get_adapter()

  -- Always show tables and views
  table.insert(lines, "  ▸ TABLES (" .. #schema.table_list .. ")")
  table.insert(lines, "  ▸ VIEWS (" .. #schema.view_list .. ")")

  -- Conditionally show based on adapter features
  if adapter.features.procedures then
    table.insert(lines, "  ▸ PROCEDURES (" .. #schema.procedure_list .. ")")
  end

  if adapter.features.functions then
    table.insert(lines, "  ▸ FUNCTIONS (" .. #schema.function_list .. ")")
  end

  if adapter.features.sequences then
    table.insert(lines, "  ▸ SEQUENCES (" .. #schema.sequence_list .. ")")
  end

  if adapter.features.synonyms then
    table.insert(lines, "  ▸ SYNONYMS (" .. #schema.synonym_list .. ")")
  end

  return lines
end
```

---

## Configuration (Multi-Database)

```lua
require('ssns').setup({
  connections = {
    -- SQL Server
    dev_mssql = 'sqlserver://localhost/DevDB',
    prod_mssql = 'sqlserver://prod-server/ProdDB',

    -- PostgreSQL
    dev_pg = 'postgres://localhost:5432/devdb',

    -- MySQL
    dev_mysql = 'mysql://localhost:3306/myapp',

    -- SQLite
    local_db = 'sqlite://./data/local.db',

    -- BigQuery
    analytics = 'bigquery://my-project/analytics_dataset',
  }
})
```

---

## Benefits of This Architecture

1. **Write Once**: Classes work for ALL databases
2. **Extend Easily**: Add new database = write one adapter
3. **Feature Detection**: UI adapts to database capabilities
4. **Type Safety**: Universal types, adapter handles conversion
5. **Testable**: Mock adapters for testing
6. **Maintainable**: Database changes = update one adapter

---

## File Organization

```
lua/ssns/
├── classes/           # Universal (ALL databases)
│   ├── base.lua
│   ├── server.lua
│   ├── database.lua
│   ├── schema.lua
│   ├── table.lua
│   ├── column.lua
│   ├── view.lua
│   ├── procedure.lua
│   ├── function.lua
│   ├── synonym.lua     # SQL Server only
│   ├── sequence.lua    # PostgreSQL, Oracle
│   ├── index.lua
│   ├── constraint.lua
│   └── parameter.lua
│
├── adapters/          # Database-specific
│   ├── base.lua       # Interface
│   ├── factory.lua    # Create adapter from connection string
│   ├── sqlserver.lua  # SQL Server implementation
│   ├── postgres.lua   # PostgreSQL implementation
│   ├── mysql.lua      # MySQL implementation
│   ├── sqlite.lua     # SQLite implementation
│   ├── bigquery.lua   # BigQuery implementation
│   └── oracle.lua     # Oracle implementation (future)
```

---

## Adding a New Database

To support a new database, create ONE adapter:

```lua
-- lua/ssns/adapters/newdb.lua
local BaseAdapter = require('ssns.adapters.base')

local NewDbAdapter = {}
setmetatable(NewDbAdapter, { __index = BaseAdapter })

NewDbAdapter.db_type = "newdb"
NewDbAdapter.features = {
  schemas = true,  -- Adjust based on database
  synonyms = false,
  procedures = true,
  functions = true,
  sequences = false,
  indexes = true,
  foreign_keys = true,
}

-- Implement query methods
function NewDbAdapter:get_databases_query()
  return "SELECT ..."
end

-- Implement all required methods from BaseAdapter
```

That's it! All classes automatically work with the new database.

---

## Success Criteria

- [ ] SQL Server support (priority 1)
- [ ] PostgreSQL support
- [ ] MySQL support
- [ ] SQLite support
- [ ] BigQuery support (nice to have)
- [ ] Adding new database takes <4 hours
- [ ] Zero changes to universal classes when adding database
- [ ] Feature detection works correctly
- [ ] UI adapts to database capabilities

---

**One class hierarchy, many databases!** 🚀
