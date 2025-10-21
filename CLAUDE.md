# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

vim-dadbod-ui is a Neovim/Vim plugin that provides a simple UI for [vim-dadbod](https://github.com/tpope/vim-dadbod). It allows users to navigate through databases and their objects, execute queries, and save queries for later use. The plugin supports multiple database systems including SQL Server, PostgreSQL, MySQL, and others.

## Core Architecture

### Plugin Structure

The codebase follows standard Vim plugin conventions:

- **autoload/db_ui.vim**: Main plugin entry point and instance management. Contains `s:dbui_instance` singleton and public API functions (`db_ui#open()`, `db_ui#get_conn_info()`, etc.)
- **autoload/db_ui/**: Module system with specialized components:
  - `drawer.vim`: UI drawer management (tree view of databases/tables)
  - `query.vim`: Query buffer creation, execution, and management
  - `schemas.vim`: Database metadata fetching and **caching system** (critical for performance)
  - `connections.vim`: Connection management (from env vars, g:dbs, saved files)
  - `table_helpers.vim`: Predefined query helpers per database scheme
  - `object_helpers.vim`: SSMS-style object actions (SELECT, EXEC, ALTER, DROP)
  - `notifications.vim`: User notifications (supports nvim-notify, echo, floating windows)
  - `lualine_colors.vim`: Lualine integration for connection status display
  - `filter.vim`: Database object filtering
  - `utils.vim`: Shared utilities
- **plugin/db_ui.vim**: Plugin initialization, global variables, commands, autocommands
- **ftplugin/**: Filetype-specific behavior (dbui, sql, dbout, etc.)
- **lua/lualine/components/db_ui.lua**: Lualine component for displaying active database connection

### Key Data Structures

**Database Entry (s:dbui.generate_new_db_entry):**
```vim
{
  'name': 'connection_name',
  'key_name': 'unique_key',
  'url': 'connection_url',
  'conn': db#connect(url),  " Active connection
  'scheme': 'sqlserver'|'postgresql'|'mysql'|etc,
  'expanded': 0|1,
  'is_server': 0|1,  " SSMS-style: server-level vs database-level
  'buffers': { 'expanded': 0, 'list': [], 'tmp': [] },
  'saved_queries': { 'expanded': 0, 'list': [] },
  'tables': { 'expanded': 0, 'list': [], 'items': {} },
  'schemas': { 'expanded': 0, 'list': [], 'items': {} },
  'object_types': {  " SSMS-style object categorization
    'tables': { 'expanded': 0, 'items': {}, 'list': [] },
    'views': { ... },
    'procedures': { ... },
    'functions': { ... }
  }
}
```

**Buffer Variables (set in query buffers):**
- `b:dbui_db_key_name`: Unique database connection identifier
- `b:dbui_table_name`: Current table name (if viewing table)
- `b:dbui_schema_name`: Current schema name
- `b:db`: Database connection object (from vim-dadbod)

### Database Metadata & Caching

**Critical Performance Feature**: `autoload/db_ui/schemas.vim` implements a TTL-based caching system:

- **Cache structure**: `s:query_cache = { 'cache_key': { 'data': [...], 'timestamp': 12345 } }`
- **Cache key format**: `db_name|query_hash`
- **Default TTL**: 300 seconds (5 minutes), configurable via `g:db_ui_cache_ttl`
- **Cache functions**:
  - `db_ui#schemas#clear_cache()` - Clear all cached results
  - `db_ui#schemas#clear_cache_for(db_name)` - Clear specific database cache
  - `s:is_cache_valid(cache_key)` - Check if cached result is within TTL
  - `s:get_cached_result(cache_key)` - Retrieve cached data
  - `s:cache_result(cache_key, result)` - Store result in cache

**Available Metadata Query Functions** (all in `autoload/db_ui/schemas.vim`):
- `db_ui#schemas#query_databases(db)` - List all databases on a server
- `db_ui#schemas#query_tables(db)` - Get tables
- `db_ui#schemas#query_views(db)` - Get views
- `db_ui#schemas#query_procedures(db)` - Get stored procedures
- `db_ui#schemas#query_functions(db)` - Get functions
- `db_ui#schemas#query_columns(db, table_name)` - Get columns with data types
- `db_ui#schemas#query_indexes(db, table_name)` - Get indexes
- `db_ui#schemas#query_primary_keys(db, table_name)` - Get primary keys
- `db_ui#schemas#query_foreign_keys(db, table_name)` - Get foreign keys
- `db_ui#schemas#query_constraints(db, table_name)` - Get constraints
- `db_ui#schemas#query_parameters(db, procedure_name)` - Get procedure/function parameters

These functions automatically leverage the caching system for performance.

### SSMS-Style Features

The plugin has been enhanced with SQL Server Management Studio (SSMS) style features:

**Enabled via**: `let g:db_ui_use_ssms_style = 1`

**Server-Level Connections**: Connect to a database server without specifying a database:
```vim
let g:dbs = {
  'dev_server': 'sqlserver://localhost',  " No database specified
  'pg_server': 'postgresql://localhost:5432'
}
```

**Object Type Categorization**: When SSMS mode is enabled, databases are organized by object types (TABLES, VIEWS, PROCEDURES, FUNCTIONS) rather than mixing all objects together.

**Object Actions** (`autoload/db_ui/object_helpers.vim`):
- SELECT - Generate SELECT query
- EXEC - Execute procedure/function
- ALTER - Auto-fetch object definition for editing
- DROP - Generate DROP statement
- DEPENDENCIES - Show object dependencies

### Integration with vim-dadbod-completion

**Critical Integration Point** (in `autoload/db_ui/query.vim` and `autoload/db_ui.vim`):

```vim
" After setting up buffer variables, trigger completion cache
if exists('*vim_dadbod_completion#fetch')
  call vim_dadbod_completion#fetch(bufnr(''))
endif
```

The completion plugin uses `db_ui#get_conn_info(db_key_name)` to retrieve:
- Connection URL
- Active connection object
- List of tables
- List of schemas
- Database scheme type

## Testing

**Test Framework**: [vim-themis](https://github.com/thinca/vim-themis)

**Run tests**: `./run.sh` (clones dependencies and runs themis)

**Test file naming**: `test/test-{feature-name}.vim`

**Test structure example**:
```vim
let s:suite = themis#suite('Feature name')
let s:expect = themis#helper('expect')

function! s:suite.before() abort
  call SetupTestDbs()
endfunction

function! s:suite.after() abort
  call Cleanup()
endfunction

function! s:suite.should_do_something() abort
  " Test code
  call s:expect(result).to_equal(expected)
endfunction
```

## Common Development Commands

### Running Tests
```bash
./run.sh                    # Run all tests
```

### Manual Testing
```vim
:DBUI                       # Open database UI drawer
:DBUIToggle                 # Toggle drawer
:DBUIAddConnection          # Add new connection
:DBUIFindBuffer             # Find current buffer in drawer
:DBUIClearCache             # Clear all cached metadata
:DBUIClearCacheFor mydb     # Clear cache for specific database
```

## Important Configuration Variables

**Performance & Caching**:
- `g:db_ui_cache_enabled` (default: 1) - Enable metadata caching
- `g:db_ui_cache_ttl` (default: 300) - Cache TTL in seconds
- `g:db_ui_max_items_per_page` (default: 500) - Pagination threshold
- `g:db_ui_show_loading_indicator` (default: 1) - Show loading messages

**SSMS-Style Features**:
- `g:db_ui_use_ssms_style` (default: 0) - Enable SSMS-style mode
- `g:db_ui_hide_system_databases` (default: 1) - Hide system databases (master, msdb, etc.)
- `g:db_ui_show_schema_prefix` (default: 1) - Show [schema].[object] format

**Connection Sources** (in order of precedence):
1. Saved connections file (`g:db_ui_save_location`)
2. `g:dbs` variable (dict or array)
3. Environment variables (`$DBUI_URL` / `$DBUI_NAME`)
4. Dotenv variables with prefix (`DB_UI_*` by default)

## Code Conventions

### VimScript Style
- Use `abort` on all functions
- Use `s:` prefix for script-local variables/functions
- Use descriptive variable names
- Add comments for complex logic
- Follow existing indentation (2 spaces)

### Error Handling
```vim
" Use notifications module for user-facing messages
call db_ui#notifications#error('Error message')
call db_ui#notifications#info('Info message')
call db_ui#notifications#warning('Warning message')
```

### Performance Considerations
- **Always use caching for metadata queries** - Never bypass the cache in `db_ui#schemas#query_*` functions
- For large databases (500+ objects), enable pagination via `g:db_ui_max_items_per_page`
- Use async query execution (already implemented via vim-dadbod's async support)
- Lazy-load database objects (only fetch when expanded)

### Buffer Management
Query buffers are created in two locations:
1. **Temporary**: `tempname()` directory (default) - deleted on Vim exit
2. **Persistent**: `g:db_ui_save_location` - saved queries for later use

Track temporary buffers in `db.buffers.tmp` for cleanup.

## Plugin Entry Points

**User Commands** (defined in `plugin/db_ui.vim`):
- `:DBUI` → `db_ui#open()`
- `:DBUIToggle` → `db_ui#toggle()`
- `:DBUIClose` → `db_ui#close()`
- `:DBUIAddConnection` → `db_ui#connections#add()`
- `:DBUIFindBuffer` → `db_ui#find_buffer()`
- `:DBUIClearCache` → `db_ui#schemas#clear_cache()`
- `:DBUIChangeConnection` → `db_ui#change_connection()` (switch connection for current buffer)

**Autoload Functions** (public API):
- `db_ui#get_conn_info(db_key_name)` - Used by vim-dadbod-completion
- `db_ui#connections_list()` - Get all configured connections
- `db_ui#save_dbout(file)` - Save query results

**Autocommands**:
- `User *DBExecutePre` - Fired before query execution
- `User *DBExecutePost` - Fired after query execution

## Database Scheme-Specific Logic

Different database types have different metadata query implementations in `autoload/db_ui/schemas.vim`:

**SQL Server** (`sqlserver`, `sqlsrv`):
- Uses `INFORMATION_SCHEMA` and system views
- Supports schemas (`dbo`, `sys`, etc.)
- Procedure parameters from `INFORMATION_SCHEMA.PARAMETERS`

**PostgreSQL** (`postgresql`, `postgres`):
- Uses `pg_catalog` and `information_schema`
- Schema support via `pg_namespace`
- Views configurable via `g:db_ui_use_postgres_views`

**MySQL/MariaDB** (`mysql`):
- Database-level objects (no schema concept)
- Uses `INFORMATION_SCHEMA`
- SHOW TABLES/COLUMNS commands

When adding new database support or modifying queries, follow the pattern in `s:get_query_for_{database_type}` functions.

## Lualine Integration

The plugin provides a lualine component (`lua/lualine/components/db_ui.lua`) that displays the current database connection in the statusline.

**Features**:
- Shows `server → database → table` hierarchy
- Color-coded connections (e.g., red for production, green for dev)
- Interactive color setting via `:DBUISetLualineColor`
- Colors persist in `{g:db_ui_save_location}/lualine_colors.json`

**Implementation details** (`autoload/db_ui/lualine_colors.vim`):
- JSON-based color storage
- Pattern matching support (`prod*`, `*_dev`, etc.)
- Exact match takes precedence over patterns

## Feature Development Guidelines

### Adding New Database Metadata Queries

1. Add query function in `autoload/db_ui/schemas.vim`:
```vim
function! db_ui#schemas#query_new_object_type(db, ...) abort
  let cache_key = s:generate_cache_key(a:db, 'new_object_type')
  let cached = s:get_cached_result(cache_key)
  if !empty(cached) | return cached | endif

  " Execute query based on db.scheme
  let query = s:get_query_for_new_object_type(a:db)
  let results = db#query(a:db.conn, query)

  call s:cache_result(cache_key, results)
  return results
endfunction
```

2. Add database-specific query strings
3. Update object type handling in `autoload/db_ui/drawer.vim` if needed

### Adding New Commands

1. Define command in `plugin/db_ui.vim`
2. Implement function in appropriate `autoload/db_ui/*.vim` module
3. Add help documentation in `doc/dadbod-ui.txt`
4. Add test in `test/test-{feature}.vim`

### Adding Configuration Options

1. Add default in `plugin/db_ui.vim` using `get(g:, 'var_name', default_value)`
2. Document in `doc/dadbod-ui.txt` under settings section
3. Use the variable in implementation code

## File Organization Notes

- **DO NOT** create new files in project root (except documentation like CLAUDE.md)
- Place Vim code in `autoload/db_ui/*.vim` (modular) or `autoload/db_ui.vim` (core)
- Place Lua code in `lua/` following standard Neovim structure
- Place tests in `test/` with `test-` prefix
- Update `doc/dadbod-ui.txt` for user-facing features
