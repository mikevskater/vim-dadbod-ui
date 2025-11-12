# Quick Start Guide - Real Database Testing

## TL;DR - Get Testing in 2 Minutes! ⚡

### Step 1: Run Any Test Command

The config file is created automatically on first use!

```vim
:DBUITestConnection sqlserver
```

You'll see:
```
ℹ️  No test config found, creating default at: ~/.local/share/nvim/dadbod_ui/test_config_override.lua
✅ Created default test config: ~/.local/share/nvim/dadbod_ui/test_config_override.lua
   Edit this file to configure your database connections
```

### Step 2: Edit the Config

```vim
:DBUITestConfig
```

This opens the config file. Update with your connection strings:

```lua
return {
  localhost_servers = {
    -- Add YOUR connection strings here
    sqlserver = "sqlserver://sa:YourPassword@localhost",
    mysql = "mysql://root:password@localhost",
    postgresql = "postgresql://postgres:password@localhost",
    sqlite = "sqlite://./test_dbui.db",  -- Already works!
  },
}
```

Save and close (`:wq`)

### Step 3: Run Tests!

```vim
:DBUITestConnection sqlserver  " Test SQL Server
:DBUITestConnection mysql      " Test MySQL
:DBUITestAllConnections        " Test all configured databases
```

That's it! 🎉

---

## New Commands

### `:DBUITestConfig`
Opens your test configuration file in the editor.
- Auto-creates the file if it doesn't exist
- Pre-filled with examples and comments
- Located at:
  - **Windows**: `C:\Users\<You>\AppData\Local\nvim-data\dadbod_ui\test_config_override.lua`
  - **Linux/Mac**: `~/.local/share/nvim/dadbod_ui/test_config_override.lua`

### `:DBUITestConfigStatus`
Shows which databases are configured:

```
Database Test Configuration Status:
============================================================
  sqlserver       ✅ Configured
  mysql           ✅ Configured
  postgresql      ❌ Not configured
  sqlite          ✅ Configured
  bigquery        ❌ Not configured
  oracle          ❌ Not configured

Test DB Name: dbui_test_db
Skip Cleanup: false
============================================================
```

### `:DBUITestConnection <type>`
Run tests for a specific database type:
```vim
:DBUITestConnection sqlserver
:DBUITestConnection mysql
:DBUITestConnection postgresql
:DBUITestConnection sqlite
```

### `:DBUITestAllConnections`
Run tests for all configured databases.

---

## What Happens Automatically

### First Time Setup (Automatic!)

1. **First test run** → Config file auto-created with defaults
2. **You edit config** → Add your connection strings
3. **Run tests again** → Tests run against your databases!

No manual file creation needed!

### Each Test Run

For each database type:

1. ✅ **Check configured** → Skip if not set in config
2. ✅ **Check server available** → Skip if can't connect
3. 🔨 **Create test database** → `dbui_test_db` (drops existing)
4. 📝 **Populate test objects** → Tables, views, procedures, functions
5. 🧪 **Run ~27 tests** → Against real database with real data
6. 🧹 **Clean up** → Drop test database (automatic!)

---

## Configuration File Location

### Automatic Location

The config is created at:
- **Windows**: `%LOCALAPPDATA%\nvim-data\dadbod_ui\test_config_override.lua`
  - Usually: `C:\Users\<YourName>\AppData\Local\nvim-data\dadbod_ui\test_config_override.lua`
- **Linux/Mac**: `~/.local/share/nvim/dadbod_ui/test_config_override.lua`

### Quick Access

```vim
" Open config file
:DBUITestConfig

" Check config status
:DBUITestConfigStatus

" Find config location
:lua print(require('db_ui.tests.test_config').get_user_config_path())
```

---

## Example Configurations

### Minimal (SQLite Only)

```lua
return {
  localhost_servers = {
    sqlite = "sqlite://./test_dbui.db",  -- Default, always works
  },
}
```

### Local Development

```lua
return {
  localhost_servers = {
    sqlserver = "sqlserver://sa:DevPassword123@localhost",
    mysql = "mysql://root:DevPassword123@localhost",
    postgresql = "postgresql://postgres:DevPassword123@localhost",
    sqlite = "sqlite://./test_dbui.db",
  },
  verbose = true,  -- Show detailed logs
}
```

### Docker Containers

```lua
return {
  localhost_servers = {
    sqlserver = "sqlserver://sa:YourStrong@Passw0rd@localhost:1433",
    mysql = "mysql://root:my-secret-pw@localhost:3306",
    postgresql = "postgresql://postgres:postgres@localhost:5432",
  },
}
```

### Windows Named Instances

```lua
return {
  localhost_servers = {
    sqlserver = "sqlserver://localhost\\SQLEXPRESS",  -- Named instance
  },
}
```

### Cloud Databases

```lua
return {
  localhost_servers = {
    sqlserver = "sqlserver://user:pass@myserver.database.windows.net",  -- Azure SQL
    bigquery = "bigquery:my-project-id",  -- BigQuery
  },
}
```

---

## Debugging

### Keep Test Database

Set `skip_cleanup = true` to keep the test database for manual inspection:

```lua
return {
  skip_cleanup = true,  -- Don't delete test DB
  verbose = true,       -- Show detailed logs
}
```

Then connect manually:
```bash
# SQL Server
sqlcmd -S localhost -d dbui_test_db -Q "SELECT * FROM test_schema.users"

# MySQL
mysql -h localhost -D dbui_test_db -e "SELECT * FROM users"

# PostgreSQL
psql -h localhost -d dbui_test_db -c "SELECT * FROM test_schema.users"
```

### Verbose Logging

```lua
return {
  verbose = true,  -- See all setup/teardown steps
}
```

Shows:
- Connection attempts
- Database creation SQL
- Population queries
- Cleanup status

---

## Common Workflows

### First Time User

```vim
" 1. Run any test (config auto-created)
:DBUITestConnection sqlite

" 2. Edit config to add your databases
:DBUITestConfig

" 3. Run tests for configured databases
:DBUITestAllConnections
```

### Daily Development

```vim
" Quick check - test all configured databases
:DBUITestAllConnections

" Or test specific database you're working on
:DBUITestConnection mysql
```

### Troubleshooting

```vim
" Check what's configured
:DBUITestConfigStatus

" Edit configuration
:DBUITestConfig

" Test with verbose logging
" (Edit config: set verbose = true)

" Test specific database with debug info
:DBUITestConnection sqlserver
```

---

## What Gets Tested

For each database type, **~27 real database tests**:

### Connection Tests
- ✅ URL parsing
- ✅ Scheme detection
- ✅ Credential handling

### Schema Queries
- ✅ List databases
- ✅ List tables (finds `users`, `posts`)
- ✅ List views (finds `user_posts_view`)
- ✅ List procedures (finds `get_user_by_id`)
- ✅ List functions (finds `get_user_count`)

### Metadata Queries
- ✅ Get columns (finds `id`, `username`, `email`)
- ✅ Get primary keys (finds `id`)
- ✅ Get foreign keys (finds `user_id` → `users.id`)
- ✅ Get constraints

### Query Execution
- ✅ SELECT queries
- ✅ INSERT queries
- ✅ COUNT(*) aggregates
- ✅ Schema-qualified names (`schema.table`)

### Cache System
- ✅ Cache enabled
- ✅ Caching behavior
- ✅ Cache clearing

### SSMS Features
- ✅ SSMS style enabled
- ✅ Schema prefix support
- ✅ System database hiding

---

## Tips

### 🔥 Use SQLite for Quick Validation

SQLite requires no server setup:
```vim
:DBUITestConnection sqlite
```

This verifies the testing framework works before configuring servers!

### 🎯 Configure Only What You Have

Just set the databases you have installed locally:
```lua
return {
  localhost_servers = {
    mysql = "mysql://root:password@localhost",  -- I have MySQL
    -- Leave others as nil
  },
}
```

Tests automatically skip unconfigured databases!

### 📊 Check Status Often

```vim
:DBUITestConfigStatus
```

Shows at a glance which databases are ready for testing.

### 🐛 Debug with Verbose + Skip Cleanup

```lua
return {
  verbose = true,      -- See what's happening
  skip_cleanup = true, -- Keep test DB to inspect
}
```

---

## Summary

**The config file is created automatically!** Just:

1. Run any test command
2. Edit config with `:DBUITestConfig`
3. Add your connection strings
4. Run tests!

No manual file creation, no complex setup. It just works! ✨
