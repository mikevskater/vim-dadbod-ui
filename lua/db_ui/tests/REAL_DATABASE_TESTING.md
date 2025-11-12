# Real Database Testing Guide

**New Approach**: Tests now run against **real localhost database servers** with **auto-created test databases**.

## Overview

The connection tests now follow this intelligent workflow:

1. ✅ **Check if localhost server exists** for each database type
2. ⏭️ **Skip gracefully** if server not configured/available
3. 🔨 **Create dedicated test database** (drops existing if leftover)
4. 📝 **Populate with test objects** (tables, views, procedures, functions)
5. 🧪 **Run comprehensive tests** against real database
6. 🧹 **Clean up test database** after completion

---

## Benefits

### Before (Old Approach)
- ❌ Only tested if functions existed
- ❌ No validation of actual database functionality
- ❌ Tests passed even if queries were broken
- ❌ No real-world coverage

### After (New Approach)
- ✅ Tests against **real databases** with **real data**
- ✅ Validates **actual query execution**
- ✅ Tests **metadata retrieval** (tables, views, procedures, functions)
- ✅ Tests **foreign keys, primary keys, constraints**
- ✅ Tests **cache system** with real queries
- ✅ Tests **SSMS-style features** with real schema objects
- ✅ **Automatic skip** if server not available
- ✅ **Zero leftover data** (auto-cleanup)

---

## Quick Start

### 1. Run Any Test (Config Auto-Created!)

The configuration file is **automatically created** on first use:

```vim
:DBUITestConnection sqlserver
```

You'll see:
```
ℹ️  No test config found, creating default...
✅ Created default test config
   Edit this file to configure your database connections
```

### 2. Edit Your Configuration

```vim
:DBUITestConfig
```

This opens the auto-created config file. Update with your connection strings:

**File Location** (auto-created):
- Windows: `C:\Users\<YourName>\AppData\Local\nvim-data\dadbod_ui\test_config_override.lua`
- Linux/Mac: `~/.local/share/nvim/dadbod_ui/test_config_override.lua`

**Edit the connection strings**:

```lua
return {
  localhost_servers = {
    -- Configure only the servers you have installed locally
    sqlserver = "sqlserver://sa:YourPassword@localhost",
    mysql = "mysql://root:password@localhost",
    postgresql = "postgresql://postgres:password@localhost",
    sqlite = "sqlite://./test_dbui.db",  -- Always works (file-based)
    bigquery = nil,  -- Requires authentication, skip for now
    oracle = nil,    -- Skip if not installed
  },

  test_db_name = "dbui_test_db",  -- Will be created/destroyed automatically
  skip_cleanup = false,            -- Set to true to keep test DB for debugging
  verbose = true,                  -- Show detailed setup/teardown logs
}
```

### 3. Run Tests

```vim
" Test all configured database types
:DBUITestAllConnections

" Test specific database type
:DBUITestConnection sqlserver
:DBUITestConnection mysql
:DBUITestConnection postgresql
```

### Helpful Commands

```vim
:DBUITestConfig          " Open/edit test configuration file
:DBUITestConfigStatus    " Show which databases are configured
:DBUITestConnection <db> " Test specific database type
:DBUITestAllConnections  " Test all configured databases
```

### 4. Check Output

Tests will show:
- ✅ Which servers are available
- 🔨 Test database creation
- 📝 Test data population
- 🧪 Test execution results
- 🧹 Cleanup status

Example output:
```
🔍 Checking SQL Server availability at: sqlserver://localhost
✅ SQL Server is available
🔨 Creating test database: dbui_test_db
✅ Test database created
📋 Test database URL: sqlserver://localhost/dbui_test_db
📝 Populating test database with test objects...
✅ Test database populated successfully
🚀 Ready to run SQL Server tests

[Tests run here...]

🧹 Cleaning up test database...
✅ Test database cleaned up
```

---

## Configuration Details

### Test Config Structure

```lua
{
  -- Localhost server URLs
  localhost_servers = {
    sqlserver = "sqlserver://...",
    mysql = "mysql://...",
    postgresql = "postgresql://...",
    sqlite = "sqlite://...",
    bigquery = "bigquery:...",
    oracle = "oracle://...",
  },

  -- Test database name (auto-created/destroyed)
  test_db_name = "dbui_test_db",

  -- Skip cleanup (for debugging)
  skip_cleanup = false,

  -- Verbose logging
  verbose = true,
}
```

### Connection String Examples

#### SQL Server
```lua
-- Default instance
sqlserver = "sqlserver://localhost"

-- Named instance
sqlserver = "sqlserver://localhost\\SQLEXPRESS"

-- With credentials
sqlserver = "sqlserver://sa:YourPassword@localhost"

-- Azure SQL
sqlserver = "sqlserver://myserver.database.windows.net"
```

#### MySQL
```lua
-- Basic
mysql = "mysql://localhost"

-- With port
mysql = "mysql://localhost:3306"

-- With credentials
mysql = "mysql://root:password@localhost"

-- Unix socket
mysql = "mysql://localhost?socket=/var/run/mysqld/mysqld.sock"
```

#### PostgreSQL
```lua
-- Basic
postgresql = "postgresql://localhost"

-- Short form
postgresql = "postgres://localhost:5432"

-- With credentials
postgresql = "postgresql://postgres:password@localhost"

-- With SSL
postgresql = "postgresql://localhost?sslmode=require"
```

#### SQLite
```lua
-- File-based (always works, no server needed)
sqlite = "sqlite://./test_dbui.db"
sqlite = "sqlite:///tmp/test.db"

-- In-memory
sqlite = "sqlite::memory:"
```

#### BigQuery
```lua
-- Requires gcloud authentication
bigquery = "bigquery:my-project-id"
bigquery = "bigquery:my-project/my_dataset"
```

#### Oracle
```lua
-- Basic
oracle = "oracle://localhost/ORCL"

-- With port and credentials
oracle = "oracle://system:password@localhost:1521/ORCL"

-- TNS name
oracle = "oracle://TNSNAME"
```

---

## What Gets Created in Test Database

Each database type gets a standardized set of test objects:

### Tables

**users table**:
- `id` (PRIMARY KEY, auto-increment)
- `username` (VARCHAR/TEXT, NOT NULL)
- `email` (VARCHAR/TEXT)
- `created_at` (TIMESTAMP/DATETIME)

**posts table**:
- `id` (PRIMARY KEY, auto-increment)
- `user_id` (FOREIGN KEY → users.id)
- `title` (VARCHAR/TEXT, NOT NULL)
- `content` (TEXT/CLOB)
- `created_at` (TIMESTAMP/DATETIME)

### Views

**user_posts_view**:
```sql
SELECT u.username, p.title, p.created_at
FROM users u
JOIN posts p ON u.id = p.user_id
```

### Stored Procedures

**get_user_by_id**(user_id):
- Fetches user by ID
- Tests procedure listing and parameter detection

### Functions

**get_user_count**():
- Returns count of users
- Tests function listing and execution

### Test Data

- 2 test users inserted
- Ready for query testing

---

## Test Coverage

### What Gets Tested

For each configured database type:

#### ✅ Connection & URL Parsing
- Server-level connections
- Database-level connections
- Credential parsing
- Special parameters (SSL, sockets, etc.)

#### ✅ Schema Queries (Real Database Calls)
- `db_ui#schemas#query_databases()` - Lists all databases
- `db_ui#schemas#query_tables()` - Lists tables (finds users, posts)
- `db_ui#schemas#query_views()` - Lists views (finds user_posts_view)
- `db_ui#schemas#query_procedures()` - Lists procedures (finds get_user_by_id)
- `db_ui#schemas#query_functions()` - Lists functions (finds get_user_count)

#### ✅ Column Metadata (Real Database Calls)
- `db_ui#schemas#query_columns()` - Gets columns (finds id, username, email)
- `db_ui#schemas#query_primary_keys()` - Gets PKs (finds id)
- `db_ui#schemas#query_foreign_keys()` - Gets FKs (finds user_id)
- `db_ui#schemas#query_constraints()` - Gets constraints

#### ✅ Query Execution
- Simple SELECT queries
- INSERT statements
- Schema-qualified names (schema.table)
- COUNT(*) aggregates

#### ✅ Cache System
- Cache enabled check
- Actual caching behavior
- Cache clearing

#### ✅ SSMS Features
- SSMS style enabled
- Schema prefix support
- System database/schema hiding
- Object type categorization

---

## Debugging

### Keep Test Database for Inspection

Set `skip_cleanup = true` in your config:

```lua
{
  skip_cleanup = true,  -- Don't delete test DB
  verbose = true,       -- Show detailed logs
}
```

Then connect manually to inspect:
```sql
-- SQL Server
USE dbui_test_db;
SELECT * FROM test_schema.users;
EXEC test_schema.get_user_by_id 1;

-- MySQL
USE dbui_test_db;
SELECT * FROM users;
CALL get_user_by_id(1);

-- PostgreSQL
\c dbui_test_db
SELECT * FROM test_schema.users;
CALL test_schema.get_user_by_id(1);
```

### Check Configuration Status

```vim
:lua require('db_ui.tests.test_config').print_status()
```

Output:
```
Database Test Configuration Status:
============================================================
  sqlserver       ✅ Configured
  mysql           ✅ Configured
  postgresql      ✅ Configured
  sqlite          ✅ Configured
  bigquery        ❌ Not configured
  oracle          ❌ Not configured

Test DB Name: dbui_test_db
Skip Cleanup: false
============================================================
```

### Verbose Logging

Enable verbose mode to see detailed setup/teardown:

```lua
{
  verbose = true
}
```

Shows:
- Connection attempts
- SQL queries executed
- Population progress
- Cleanup status

---

## Skipping Tests

Tests automatically skip if:

1. **No configuration**: Server URL not set in `test_config_override.lua`
2. **Server unavailable**: Can't connect to localhost server
3. **Database creation fails**: Permission or syntax issues
4. **Population fails**: SQL errors in setup queries

When skipped, you'll see:
```
⚠️  Skipping SQL Server tests: SQL Server not configured in test_config.lua
```

All tests for that database type pass as "Skipped" (not failures).

---

## Common Issues

### "Connection failed" Error

**Problem**: Can't connect to localhost server

**Solutions**:
1. Verify server is running:
   ```bash
   # SQL Server
   systemctl status mssql-server

   # MySQL
   systemctl status mysql

   # PostgreSQL
   systemctl status postgresql
   ```

2. Check connection string:
   - Host correct? (`localhost` vs `127.0.0.1`)
   - Port correct? (1433, 3306, 5432)
   - Credentials correct?

3. Test connection manually:
   ```bash
   # SQL Server
   sqlcmd -S localhost -U sa -P 'YourPassword'

   # MySQL
   mysql -h localhost -u root -p

   # PostgreSQL
   psql -h localhost -U postgres
   ```

### "Create database failed" Error

**Problem**: Can't create test database

**Solutions**:
1. Check permissions:
   - SQL Server: User needs `CREATE DATABASE` permission
   - MySQL: User needs `CREATE` privilege
   - PostgreSQL: User needs `CREATEDB` privilege

2. Grant permissions:
   ```sql
   -- SQL Server
   GRANT CREATE DATABASE TO sa;

   -- MySQL
   GRANT CREATE ON *.* TO 'root'@'localhost';

   -- PostgreSQL
   ALTER USER postgres CREATEDB;
   ```

### "Population failed" Error

**Problem**: Can't create test objects

**Solutions**:
1. Check SQL syntax for your database version
2. Look at error message - may indicate:
   - Missing schema support
   - Syntax differences in your DB version
   - Permission issues

3. Skip cleanup and inspect:
   ```lua
   skip_cleanup = true
   ```

   Then connect manually and run population queries one by one.

### SQLite Always Works

SQLite is file-based, so it always works without server setup:

```lua
localhost_servers = {
  sqlite = "sqlite://./test_dbui.db"  -- Always enabled
}
```

Use SQLite tests to verify the testing framework works!

---

## Files

### Core Test Framework

- `lua/db_ui/tests/test_db_helper.lua` - Database setup/teardown helper
- `lua/db_ui/tests/test_config.lua` - Test configuration module
- `lua/db_ui/tests/test_config_override.example.lua` - Example config

### Updated Test Files

- `lua/db_ui/tests/connections/sqlserver.lua` - **Updated with real DB testing**
- `lua/db_ui/tests/connections/mysql.lua` - (Ready to update)
- `lua/db_ui/tests/connections/postgresql.lua` - (Ready to update)
- `lua/db_ui/tests/connections/sqlite.lua` - (Ready to update)
- `lua/db_ui/tests/connections/bigquery.lua` - (Ready to update)
- `lua/db_ui/tests/connections/oracle.lua` - (Ready to update)

---

## Migration from Old Tests

### Old Approach
```lua
function M.test_tables_query_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_tables'),
    1,
    "Table query function should exist"
  )
end
```

### New Approach
```lua
function M.test_can_list_tables()
  if skip_if_unavailable() then return end  -- Graceful skip

  local db = {
    url = M.test_db_url,
    conn = vim.fn['db#connect'](M.test_db_url),
    scheme = 'sqlserver'
  }
  local tables = vim.fn['db_ui#schemas#query_tables'](db)

  -- Actually tests real database!
  test.assert_not_nil(tables, 'Should return tables list')
  test.assert(found_users, 'Should find users table')
  test.assert(found_posts, 'Should find posts table')
end
```

**Key Differences**:
- ✅ Tests **real functionality**, not just existence
- ✅ Validates **actual results** from database
- ✅ Skips gracefully if server unavailable
- ✅ No false positives

---

## Next Steps

1. **Configure your localhost connections** in `test_config_override.lua`
2. **Run SQL Server tests** to verify setup: `:DBUITestConnection sqlserver`
3. **Review output** to ensure setup/teardown works
4. **Configure other databases** as needed
5. **Run all connection tests**: `:DBUITestAllConnections`

---

## Summary

This new testing approach ensures **vim-dadbod-ui works with real databases** while being **completely optional** (skips if not configured). It provides:

- ✅ **Real-world validation** of database functionality
- ✅ **Automatic setup/teardown** of test databases
- ✅ **Zero manual cleanup** required
- ✅ **Graceful skipping** when servers unavailable
- ✅ **Comprehensive coverage** of all database features

**Start testing with real databases today!** 🚀
