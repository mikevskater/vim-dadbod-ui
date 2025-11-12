# Database Connection Type Tests

Comprehensive test suites for all supported database connection types in vim-dadbod-ui.

## Overview

These tests verify that vim-dadbod-ui properly supports each database system's specific features, SQL syntax, metadata queries, and configuration options.

## Supported Database Types

| Database | Scheme(s) | Test File | Status |
|----------|-----------|-----------|--------|
| **SQL Server** | `sqlserver`, `sqlsrv`, `mssql` | `sqlserver.lua` | ✅ Complete |
| **MySQL/MariaDB** | `mysql` | `mysql.lua` | ✅ Complete |
| **PostgreSQL** | `postgresql`, `postgres` | `postgresql.lua` | ✅ Complete |
| **SQLite** | `sqlite` | `sqlite.lua` | ✅ Complete |
| **Google BigQuery** | `bigquery` | `bigquery.lua` | ✅ Complete |
| **Oracle Database** | `oracle` | `oracle.lua` | ✅ Complete |

---

## Running Connection Tests

### Run All Connection Type Tests

```vim
:DBUITestAllConnections
```

This runs all connection type tests sequentially:
- SQL Server Connections
- MySQL/MariaDB Connections
- PostgreSQL Connections
- SQLite Connections
- BigQuery Connections
- Oracle Connections

**Output**: Saved to `~/.local/share/nvim/dadbod_ui/connection_tests_<timestamp>.txt`

### Run Specific Database Type Tests

```vim
:DBUITestConnection sqlserver
:DBUITestConnection mysql
:DBUITestConnection postgresql
:DBUITestConnection sqlite
:DBUITestConnection bigquery
:DBUITestConnection oracle
```

**Output**: Saved to `~/.local/share/nvim/dadbod_ui/<db_type>_test_results_<timestamp>.txt`

---

## What These Tests Cover

### Connection URL Parsing
- Scheme detection
- Host/port parsing
- Credentials parsing
- Database/schema parsing
- Special connection parameters (SSL, sockets, etc.)

### Schema Query Functions
- Listing databases/datasets/schemas
- Listing tables
- Listing views
- Listing procedures
- Listing functions

### Column Metadata Functions
- Column information with data types
- Index information
- Primary key detection
- Foreign key relationships
- Constraint information
- Procedure/function parameters

### Database-Specific Features
- System database/schema handling
- Object type categorization
- SQL syntax support (qualified names, quoting)
- Cache configuration
- Table helpers (COUNT, TOP/LIMIT, DESCRIBE)

### Advanced Features
- Partitioning support
- Materialized views
- Triggers
- Sequences
- Extensions (database-specific)
- Special data types

---

## Test Details by Database Type

### SQL Server (`sqlserver.lua`) - 36 tests

**Connection Types**:
- Server-level: `sqlserver://localhost`
- Database-level: `sqlserver://localhost/TestDB`
- Credentials: `sqlserver://user:pass@localhost/TestDB`
- Azure SQL: `sqlserver://myserver.database.windows.net/TestDB`
- Named instance: `sqlserver://localhost\\SQLEXPRESS/TestDB`
- Integrated auth: `sqlserver://localhost/TestDB?trusted_connection=yes`

**Key Features Tested**:
- SSMS-style object categorization (tables, views, procedures, functions)
- Schema prefix support (`[schema].[table]` format)
- System database hiding (master, msdb, tempdb, model)
- System schema hiding (sys, INFORMATION_SCHEMA)
- Three-part names (`database.schema.table`)
- Four-part names (`server.database.schema.table` for linked servers)
- SQL Server table helpers (TOP 100, COUNT)
- Metadata via INFORMATION_SCHEMA and system views

### MySQL (`mysql.lua`) - 38 tests

**Connection Types**:
- Basic: `mysql://localhost/testdb`
- With port: `mysql://localhost:3306/testdb`
- Credentials: `mysql://user:pass@localhost/testdb`
- Socket: `mysql://localhost/testdb?socket=/var/run/mysqld/mysqld.sock`
- SSL: `mysql://user:pass@localhost/testdb?ssl-mode=REQUIRED`

**Key Features Tested**:
- Database-level organization (no schema concept)
- System database handling (mysql, information_schema, performance_schema, sys)
- Backtick identifier quoting
- MySQL table helpers (LIMIT, DESCRIBE, COUNT)
- Character set and collation support
- Storage engine support (InnoDB, MyISAM)
- Metadata via SHOW commands and INFORMATION_SCHEMA

### PostgreSQL (`postgresql.lua`) - 38 tests

**Connection Types**:
- Basic: `postgresql://localhost/testdb`
- With port: `postgresql://localhost:5432/testdb`
- Short scheme: `postgres://localhost/testdb`
- With schema: `postgresql://localhost/testdb?search_path=myschema`
- SSL: `postgresql://localhost/testdb?sslmode=require`
- Unix socket: `postgresql:///testdb?host=/var/run/postgresql`

**Key Features Tested**:
- Robust schema support (`schema.table` format)
- System database handling (postgres, template0, template1)
- System schema hiding (pg_catalog, information_schema)
- PostgreSQL views configuration (`g:db_ui_use_postgres_views`)
- Double-quote identifier quoting
- Extension support (PostGIS, pg_trgm, etc.)
- Custom types (ENUM, DOMAIN, COMPOSITE)
- Advanced features (materialized views, partitioning, sequences)
- Metadata via pg_catalog and information_schema

### SQLite (`sqlite.lua`) - 32 tests

**Connection Types**:
- File-based: `sqlite:///path/to/database.db`
- Relative path: `sqlite://./local.db`
- In-memory: `sqlite::memory:`
- Windows path: `sqlite://C:/Users/user/database.db`

**Key Features Tested**:
- Single-file database model
- No server concept
- Limited schema support (ATTACH DATABASE)
- Simplified object model (tables, views, indexes, triggers)
- Metadata via sqlite_master and PRAGMA commands
- Dynamic typing and type affinity
- FTS (Full-Text Search) support
- JSON1 extension support
- WAL (Write-Ahead Logging) mode
- Virtual tables

### BigQuery (`bigquery.lua`) - 32 tests

**Connection Types**:
- Basic: `bigquery:my-project`
- With dataset: `bigquery:my-project/my_dataset`
- With location: `bigquery:my-project/my_dataset?location=US`

**Key Features Tested**:
- Project/dataset/table hierarchy
- INFORMATION_SCHEMA support
- Standard SQL (not legacy SQL)
- Backtick identifier quoting
- No enforced constraints (PK, FK)
- Clustered tables instead of indexes
- Partitioned and clustered tables
- External tables (GCS, Drive)
- Materialized views
- BigQuery ML models
- Wildcard table queries
- Cost optimization via caching

### Oracle (`oracle.lua`) - 40 tests

**Connection Types**:
- Basic: `oracle://localhost/ORCL`
- With port: `oracle://localhost:1521/ORCL`
- Credentials: `oracle://user:pass@localhost/ORCL`
- Service name: `oracle://localhost/SERVICE_NAME`
- TNS name: `oracle://TNSNAME`

**Key Features Tested**:
- Schema = User model
- System schema handling (SYS, SYSTEM, DBSNMP)
- Schema prefix support (`schema.table` format)
- Database link support (`table@dblink`)
- Double-quote identifier quoting (case-sensitive)
- DUAL table
- Oracle table helpers (ROWNUM, FETCH FIRST)
- Packages (collections of procedures/functions)
- Sequences for auto-increment
- Extensive data types (VARCHAR2, NUMBER, TIMESTAMP, CLOB, BLOB)
- Advanced features (materialized views, partitioning, flashback)
- PL/SQL support (packages, anonymous blocks)
- Hierarchical queries (CONNECT BY)
- Metadata via USER_*, ALL_*, DBA_* views

---

## Test Structure

Each database-specific test file follows this structure:

```lua
-- Connection URL parsing tests
M.test_basic_connection_scheme()
M.test_connection_with_credentials()
M.test_special_connection_types()

-- Schema query function tests
M.test_databases_query_exists()
M.test_tables_query_exists()
M.test_views_query_exists()
M.test_procedures_query_exists()
M.test_functions_query_exists()

-- Column metadata tests
M.test_columns_query_exists()
M.test_indexes_query_exists()
M.test_primary_keys_query_exists()
M.test_foreign_keys_query_exists()
M.test_constraints_query_exists()
M.test_parameters_query_exists()

-- Database-specific feature tests
M.test_system_database_handling()
M.test_schema_support()
M.test_identifier_quoting()

-- Table helper tests
M.test_table_helpers_configured()
M.test_limit_query_helper()
M.test_count_query_helper()

-- Cache configuration tests
M.test_cache_enabled()
M.test_cache_ttl_configured()

-- Advanced feature tests
M.test_partitioning_support()
M.test_materialized_views()
M.test_triggers()
```

---

## Expected Test Counts

| Database | Estimated Tests | Actual Tests |
|----------|----------------|--------------|
| SQL Server | 35 | 36 |
| MySQL | 35 | 38 |
| PostgreSQL | 35 | 38 |
| SQLite | 30 | 32 |
| BigQuery | 30 | 32 |
| Oracle | 40 | 40 |
| **TOTAL** | **205** | **216** |

---

## Adding Tests for New Database Types

To add support for a new database type:

1. **Create test file**: `lua/db_ui/tests/connections/<dbtype>.lua`

2. **Follow the template**:
```lua
local M = {}
local test = require('db_ui.tests.init')

local test_connections = {
  basic = '<dbtype>://localhost/testdb',
}

function M.setup()
  -- Database-specific setup
end

-- Add tests following the structure above

return M
```

3. **Add to master suite**: Edit `lua/db_ui/tests/all_connections.lua`
```lua
local connection_suites = {
  -- ... existing suites
  { name = "YourDB Connections", module = "db_ui.tests.connections.yourdb" },
}
```

4. **Test it**:
```vim
:DBUITestConnection yourdb
```

---

## Common Assertions

The connection tests use these assertions from `db_ui.tests.init`:

```lua
-- Check function exists
test.assert_equal(vim.fn.exists('*db_ui#schemas#query_tables'), 1)

-- Check scheme parsing
test.assert_equal(parsed.scheme, 'mysql')

-- Check configuration
test.assert_equal(vim.g.db_ui_cache_enabled, 1)
test.assert_not_nil(vim.g.db_ui_cache_ttl)

-- Check contains
test.assert_contains(hide_schemas, 'sys')

-- Pattern matching
test.assert(string.find(helpers.mysql.Limit100, 'LIMIT') ~= nil)
```

---

## Database-Specific Considerations

### SQL Server
- Test both server-level and database-level connections
- Verify SSMS-style features work correctly
- Test schema prefix formatting

### MySQL
- Remember: database IS the schema in MySQL
- Test both SHOW commands and INFORMATION_SCHEMA queries
- Verify backtick quoting support

### PostgreSQL
- Test both `postgresql://` and `postgres://` schemes
- Verify schema support is robust
- Test `g:db_ui_use_postgres_views` configuration

### SQLite
- Test file paths (absolute, relative, Windows)
- Test in-memory databases
- Remember: no server concept, simplified metadata

### BigQuery
- Test project/dataset hierarchy
- Emphasize caching (cost optimization)
- Remember: no enforced constraints

### Oracle
- Test TNS name connections
- Test schema = user model
- Verify PL/SQL package support

---

## Troubleshooting

### Tests Fail to Load

**Error**: `Could not load suite: <database> Connections`

**Solution**: Check that the test file exists:
```vim
:lua print(vim.inspect(require('db_ui.tests.connections.sqlserver')))
```

### URL Parsing Failures

**Error**: `vim.fn['db#url#parse'] returns nil or wrong values`

**Cause**: vim-dadbod may not support that URL format

**Debug**:
```vim
:lua print(vim.inspect(vim.fn['db#url#parse']('sqlserver://localhost')))
```

### Function Existence Tests Fail

**Error**: `Expected: 1, Actual: 0` for function tests

**Cause**: Autoload timing - functions not loaded yet

**Solution**: Trigger autoload first in test:
```lua
vim.fn['db_ui#schemas#query_tables']({})  -- Trigger autoload
test.assert_equal(vim.fn.exists('*db_ui#schemas#query_tables'), 1)
```

---

## Integration with CI/CD

These tests can be run in CI/CD pipelines:

```bash
# Run Neovim headless with test command
nvim --headless -c "lua require('db_ui.tests.all_connections').run_all_connection_tests()" -c "qall"

# Check exit code based on test results
# (Future enhancement: add exit code support)
```

---

## Future Enhancements

Potential additions:
- [ ] Actual connection tests (with test databases)
- [ ] Query execution tests
- [ ] Transaction tests
- [ ] Performance benchmarks per database type
- [ ] Connection pooling tests
- [ ] Timeout/retry tests
- [ ] Error handling tests
- [ ] Multi-database query tests (external DB references)

---

## Summary

These comprehensive connection tests ensure vim-dadbod-ui properly supports all major database systems with their unique features, syntax, and metadata requirements. Run them regularly to verify compatibility and catch regressions.

**Quick Start**:
```vim
:DBUITestAllConnections    " Run all connection type tests
:DBUITestConnection mysql  " Run specific database tests
```

Results are saved automatically for later review!
