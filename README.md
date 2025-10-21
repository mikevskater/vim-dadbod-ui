# vim-dadbod-ui

Simple UI for [vim-dadbod](https://github.com/tpope/vim-dadbod).
It allows simple navigation through databases and allows saving queries for later use.

![screenshot](https://i.imgur.com/fhGqC9U.png)


With nerd fonts:
![with-nerd-fonts](https://i.imgur.com/aXI5BTG.png)


Video presentation by TJ:

[![Video presentation by TJ](https://i.ytimg.com/vi/ALGBuFLzDSA/hqdefault.jpg?sqp=-oaymwEcCNACELwBSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLDmOFtUnDmQx5U_PKBqV819YujOBw)](https://www.youtube.com/watch?v=ALGBuFLzDSA)

Tested on Linux, Mac and Windows, Vim 8.1+ and Neovim.

Features:
* Navigate through multiple databases and it's tables and schemas
* **SSMS-Style Server Browser**: Connect to servers and browse all databases (SQL Server, PostgreSQL, MySQL)
* Several ways to define your connections
* Save queries on single location for later use
* Define custom table helpers
* Bind parameters (see `:help vim-dadbod-ui-bind-parameters`)
* Autocompletion with [vim-dadbod-completion](https://github.com/kristijanhusak/vim-dadbod-completion)
* Jump to foreign keys from the dadbod output (see `:help <Plug>(DBUI_JumpToForeignKey)`)
* Support for nerd fonts (see `:help g:db_ui_use_nerd_fonts`)
* Async query execution
* **Performance Optimization**: Query caching and pagination for large databases

## Installation

Configuration with [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod', lazy = true },
    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true }, -- Optional
  },
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    -- Your DBUI configuration
    vim.g.db_ui_use_nerd_fonts = 1
  end,
}
```

Or [vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-ui'
Plug 'kristijanhusak/vim-dadbod-completion' "Optional
```

After installation, run `:DBUI`, which should open up a drawer with all databases provided.
When you finish writing your query, just write the file (`:w`) and it will automatically execute the query for that database.

## Databases
There are 3 ways to provide database connections to UI:

1. [Through environment variables](#through-environment-variables)
2. [Via g:dbs global variable](#via-gdbs-global-variable)
3. [Via :DBUIAddConnection command](#via-dbuiaddconnection-command)

#### Through environment variables
If `$DBUI_URL` env variable exists, it will be added as a connection. Name for the connection will be parsed from the url.
If you want to use a custom name, pass `$DBUI_NAME` alongside the url.
Env variables that will be read can be customized like this:

```vimL
let g:db_ui_env_variable_url = 'DATABASE_URL'
let g:db_ui_env_variable_name = 'DATABASE_NAME'
```

Optionally you can leverage [dotenv.vim](https://github.com/tpope/vim-dotenv)
to specific any number of connections in an `.env` file by using a specific
prefix (defaults to `DB_UI_`). The latter part of the env variable becomes the
name of the connection (lowercased)

```bash
# .env
DB_UI_DEV=...          # becomes the `dev` connection
DB_UI_PRODUCTION=...   # becomes the `production` connection
```

The prefix can be customized like this:

```vimL
let g:db_ui_dotenv_variable_prefix = 'MYPREFIX_'
```

#### Via g:dbs global variable
Provide list with all databases that you want to use through `g:dbs` variable as an array of objects or an object:

```vimL
function s:resolve_production_url()
  let url = system('get-prod-url')
  return url
end

let g:dbs = {
\ 'dev': 'postgres://postgres:mypassword@localhost:5432/my-dev-db',
\ 'staging': 'postgres://postgres:mypassword@localhost:5432/my-staging-db',
\ 'wp': 'mysql://root@localhost/wp_awesome',
\ 'production': function('s:resolve_production_url')
\ }
```

Or if you want them to be sorted in the order you define them, this way is also available:

```vimL
function s:resolve_production_url()
  let url = system('get-prod-url')
  return url
end

let g:dbs = [
\ { 'name': 'dev', 'url': 'postgres://postgres:mypassword@localhost:5432/my-dev-db' }
\ { 'name': 'staging', 'url': 'postgres://postgres:mypassword@localhost:5432/my-staging-db' },
\ { 'name': 'wp', 'url': 'mysql://root@localhost/wp_awesome' },
\ { 'name': 'production', 'url': function('s:resolve_production_url') },
\ ]
```

In case you use Neovim, here's an example with Lua:

```lua
vim.g.dbs = {
    { name = 'dev', url = 'postgres://postgres:mypassword@localhost:5432/my-dev-db' },
    { name = 'staging', url = 'postgres://postgres:mypassword@localhost:5432/my-staging-db' },
    { name = 'wp', url = 'mysql://root@localhost/wp_awesome' },
    {
      name = 'production',
      url = function()
        return vim.fn.system('get-prod-url')
      end
    },
}
```


Just make sure to **NOT COMMIT** these. I suggest using project local vim config (`:help exrc`)

#### Via :DBUIAddConnection command

Using `:DBUIAddConnection` command or pressing `A` in dbui drawer opens up a prompt to enter database url and name,
that will be saved in `g:db_ui_save_location` connections file. These connections are available from everywhere.

#### Connection related notes
It is possible to have two connections with same name, but from different source.
for example, you can have `my-db` in env variable, in `g:dbs` and in saved connections.
To view from which source the database is, press `H` in drawer.
If there are duplicate connection names from same source, warning will be shown and first one added will be preserved.

### SSMS-Style Server-Level Connections

vim-dadbod-ui supports SSMS-style server-level connections, allowing you to connect to a database server and browse all databases, similar to SQL Server Management Studio (SSMS).

#### Enabling SSMS-Style Mode

Add this to your configuration:

```vim
let g:db_ui_use_ssms_style = 1
```

Or in Lua:

```lua
vim.g.db_ui_use_ssms_style = 1
```

#### Server-Level Connection Examples

Connect to a server without specifying a database:

```vim
" VimL
let g:dbs = {
\ 'dev_server': 'sqlserver://localhost',
\ 'pg_server': 'postgresql://localhost:5432',
\ 'mysql_server': 'mysql://root@localhost'
\ }
```

```lua
-- Lua
vim.g.dbs = {
  { name = 'dev_server', url = 'sqlserver://localhost' },
  { name = 'pg_server', url = 'postgresql://localhost:5432' },
  { name = 'mysql_server', url = 'mysql://root@localhost' },
}
```

#### SSMS-Style Features

When enabled, server-level connections provide:

- **Database Browsing**: Expand server to see all databases
- **Object Types**: Each database shows TABLES, VIEWS, PROCEDURES, FUNCTIONS
- **Schema Prefix**: Objects displayed as `[schema].[name]`
- **Quick Actions**: SELECT, EXEC, ALTER, DROP, DEPENDENCIES
- **Structural Info**: Columns, Indexes, Keys, Constraints, Parameters
- **ALTER Auto-Fetch**: Click ALTER to automatically load object definition for editing
- **Database Context**: Queries automatically use correct database context

#### Performance Features

For large databases (500+ objects), automatic performance optimizations:

- **Query Caching**: Results cached for 5 minutes (configurable)
- **Pagination**: Large object lists automatically paginated
- **Loading Indicators**: Visual feedback during slow operations

```vim
" Performance configuration (optional)
let g:db_ui_cache_enabled = 1          " Enable caching (default: 1)
let g:db_ui_cache_ttl = 300            " Cache TTL in seconds (default: 300)
let g:db_ui_max_items_per_page = 500  " Pagination threshold (default: 500)
let g:db_ui_show_loading_indicator = 1 " Show loading messages (default: 1)
```

Clear cache when needed:

```vim
:DBUIClearCache              " Clear all cached results
:DBUIClearCacheFor mydb      " Clear cache for specific database
```

#### Backward Compatibility

SSMS-style mode is **opt-in**. When disabled (default), the plugin works in traditional database-level mode. Both modes can be used simultaneously:

```vim
let g:db_ui_use_ssms_style = 1

let g:dbs = {
\ 'dev_server': 'sqlserver://localhost',        " SSMS-style: browse all databases
\ 'myapp_db': 'sqlserver://localhost/myapp',    " Traditional: single database
\ }
```

#### Supported Databases

SSMS-style mode works with:
- **SQL Server** (primary target, full feature support)
- **PostgreSQL** (full support)
- **MySQL/MariaDB** (full support)

### Lualine Integration

**Note: This feature requires [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) to be installed.**

vim-dadbod-ui provides a custom lualine component that displays the current database connection information in your statusline. Similar to Redgate's SQL Server color-coding feature, you can configure different colors for different connections to visually distinguish between production, development, and other environments.

#### Basic Setup

**⚠️ IMPORTANT:** You must add the `db_ui` component to your lualine configuration for this feature to work.

Add this to your `init.lua` (or wherever you configure lualine):

```lua
require('lualine').setup {
  sections = {
    lualine_c = {
      'filename',
      'db_ui',  -- Add this component
    }
  }
}
```

After adding the component, restart Neovim or reload your config (`:source $MYVIMRC`).

The component will display the current database connection in the format: `server → schema → table`

**See [LUALINE_SETUP.md](LUALINE_SETUP.md) for detailed setup instructions and troubleshooting.**

#### Interactive Color Setting

**New in this version:** Set connection colors interactively without editing config files!

When lualine is installed, you can set colors for any database connection directly from the DBUI drawer:

1. Open the DBUI drawer (`:DBUI`)
2. Navigate to any database connection
3. Press `<Leader>c` to set the connection color (typically `\c` by default)
4. Choose from preset colors or create custom colors
5. Colors are automatically saved and persist across sessions

**Preset Colors:**
- Red (Production) - High visibility warning
- Green (Development) - Safe environment
- Yellow (Staging) - Caution
- Blue (QA/Testing)
- Orange (UAT)
- Purple (Backup/Reporting)
- Gray (Default)
- Custom - Enter your own hex colors

Colors are saved to `~/.local/share/db_ui/lualine_colors.json` (or your configured `g:db_ui_save_location`).

#### Manual Color Configuration

You can also configure colors manually in your config file to prevent accidental operations on production databases:

```lua
-- In your Neovim config (init.lua)
vim.g.db_ui_lualine_colors = {
  -- Red background for production - high visibility warning
  ['ProductionDB'] = { fg = '#ffffff', bg = '#ff0000', gui = 'bold' },
  ['prod*'] = { fg = '#ffffff', bg = '#ff0000' },  -- Pattern match

  -- Green background for development
  ['DevDB'] = { fg = '#000000', bg = '#00ff00' },
  ['*_dev'] = { fg = '#000000', bg = '#00ff00' },  -- Pattern match

  -- Yellow background for staging
  ['StagingDB'] = { fg = '#000000', bg = '#ffff00' },

  -- Blue background for local
  ['localhost'] = { fg = '#ffffff', bg = '#0000ff' },
}

-- Default color for connections not specified above
vim.g.db_ui_lualine_default_color = { fg = '#ffffff', bg = '#666666' }
```

Or in VimScript (init.vim):

```vim
let g:db_ui_lualine_colors = {
\   'ProductionDB': { 'fg': '#ffffff', 'bg': '#ff0000', 'gui': 'bold' },
\   'prod*': { 'fg': '#ffffff', 'bg': '#ff0000' },
\   'DevDB': { 'fg': '#000000', 'bg': '#00ff00' },
\   '*_dev': { 'fg': '#000000', 'bg': '#00ff00' },
\ }

let g:db_ui_lualine_default_color = { 'fg': '#ffffff', 'bg': '#666666' }
```

#### Color Configuration Options

Colors are matched in the following order:

1. **Exact match**: Connection name matches exactly (e.g., `'ProductionDB'`)
2. **Pattern match**: Using wildcards `*` and `?` (e.g., `'prod*'`, `'*production*'`, `'db_*_live'`)
3. **Default color**: Falls back to `g:db_ui_lualine_default_color`
4. **Lualine default**: If no colors configured, uses lualine's default section colors

**Color format:**
- `fg`: Foreground color (text color) - hex color code (e.g., `'#ffffff'`)
- `bg`: Background color - hex color code (e.g., `'#ff0000'`)
- `gui`: Optional text style - `'bold'`, `'italic'`, `'underline'`, or combination `'bold,italic'`

#### Advanced Component Configuration

For more control, use the component table directly:

```lua
require('lualine').setup {
  sections = {
    lualine_c = {
      {
        'db_ui',
        icon = '',  -- Custom icon (requires Nerd Fonts)
        color = function()
          -- Your custom color logic here
          return { fg = '#ffffff', bg = '#0000ff' }
        end,
      }
    }
  }
}
```

#### Example: Production Safety Setup

A recommended configuration for preventing production mistakes:

```lua
-- Bright red for production - impossible to miss
vim.g.db_ui_lualine_colors = {
  ['*prod*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*production*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*live*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },

  -- Safe green for development
  ['*dev*'] = { fg = '#000000', bg = '#00cc00' },
  ['*development*'] = { fg = '#000000', bg = '#00cc00' },
  ['localhost'] = { fg = '#000000', bg = '#00cc00' },

  -- Caution yellow for staging
  ['*staging*'] = { fg = '#000000', bg = '#cccc00' },
  ['*uat*'] = { fg = '#000000', bg = '#cccc00' },
}

-- Gray for unclassified connections
vim.g.db_ui_lualine_default_color = { fg = '#ffffff', bg = '#666666' }
```

#### Available Commands

```vim
:DBUISetLualineColor ConnectionName     " Interactively set color for a connection
:DBUIRemoveLualineColor ConnectionName  " Remove color for a connection
:DBUIListLualineColors                  " List all saved connection colors
```

**Keyboard Shortcut:** When in the DBUI drawer with lualine installed, press `<Leader>c` on any database connection to set its color (typically `\c` by default).

## Settings

An overview of all settings and their default values can be found at `:help vim-dadbod-ui`.

### Table helpers
Table helper is a predefined query that is available for each table in the list.
Currently, default helper that each scheme has for it's tables is `List`, which for most schemes defaults to `g:db_ui_default_query`.
Postgres, Mysql and Sqlite has some additional helpers defined, like "Indexes", "Foreign Keys", "Primary Keys".

Predefined query can inject current db name and table name via `{table}` and `{dbname}`.

To add your own for a specific scheme, provide it through .`g:db_ui_table_helpers`.

For example, to add a "count rows" helper for postgres, you would add this as a config:

```vimL
let g:db_ui_table_helpers = {
\   'postgresql': {
\     'Count': 'select count(*) from "{table}"'
\   }
\ }
```

Or if you want to override any of the defaults, provide the same name as part of config:
```vimL
let g:db_ui_table_helpers = {
\   'postgresql': {
\     'List': 'select * from "{table}" order by id asc'
\   }
\ }
```

### Auto execute query
If this is set to `1`, opening any of the table helpers will also automatically execute the query.

Default value is: `0`

To enable it, add this to vimrc:

```vimL
let g:db_ui_auto_execute_table_helpers = 1
```

### Icons
These are the default icons used:

```vimL
let g:db_ui_icons = {
    \ 'expanded': '▾',
    \ 'collapsed': '▸',
    \ 'saved_query': '*',
    \ 'new_query': '+',
    \ 'tables': '~',
    \ 'buffers': '»',
    \ 'connection_ok': '✓',
    \ 'connection_error': '✕',
    \ }
```

You can override any of these:
```vimL
let g:db_ui_icons = {
    \ 'expanded': '+',
    \ 'collapsed': '-',
    \ }
```

### Help text
To hide `Press ? for help` add this to vimrc:

```
let g:db_ui_show_help = 0
```

Pressing `?` will show/hide help no matter if this option is set or not.

### Drawer width

What should be the drawer width when opened. Default is `40`.

```vimL
let g:db_ui_winwidth = 30
```

### Default query

**DEPRECATED**: Use [Table helpers](#table-helpers) instead.

When opening up a table, buffer will be prepopulated with some basic select, which defaults to:
```sql
select * from table LIMIT 200;
```
To change the default value, use `g:db_ui_default_query`, where `{table}` is placeholder for table name.

```vimL
let g:db_ui_default_query = 'select * from "{table}" limit 10'
```

### Save location
All queries are by default written to tmp folder.
There's a mapping to save them permanently for later to the specific location.

That location is by default `~/.local/share/db_ui`. To change it, addd `g:db_ui_save_location` to your vimrc.
```vimL
let g:db_ui_save_location = '~/Dropbox/db_ui_queries'
```

## Mappings
These are the default mappings for `dbui` drawer:

* o / \<CR> - Open/Toggle Drawer options (`<Plug>(DBUI_SelectLine)`)
* S - Open in vertical split (`<Plug>(DBUI_SelectLineVsplit)`)
* d - Delete buffer or saved sql (`<Plug>(DBUI_DeleteLine)`)
* R - Redraw (`<Plug>(DBUI_Redraw)`)
* A - Add connection (`<Plug>(DBUI_AddConnection)`)
* H - Toggle database details (`<Plug>(DBUI_ToggleDetails)`)

For queries, filetype is automatically set to `sql`. Also, two mappings is added for the `sql` filetype:

* \<Leader>W - Permanently save query for later use (`<Plug>(DBUI_SaveQuery)`)
* \<Leader>E - Edit bind parameters (`<Plug>(DBUI_EditBindParameters)`)

Any of these mappings can be overridden:
```vimL
autocmd FileType dbui nmap <buffer> v <Plug>(DBUI_SelectLineVsplit)
```

If you don't want mappings to be added, add this to vimrc:
```vimL
let g:db_ui_disable_mappings = 1       " Disable all mappings
let g:db_ui_disable_mappings_dbui = 1  " Disable mappings in DBUI drawer
let g:db_ui_disable_mappings_dbout = 1 " Disable mappings in DB output
let g:db_ui_disable_mappings_sql = 1   " Disable mappings in SQL buffers
let g:db_ui_disable_mappings_javascript = 1   " Disable mappings in Javascript buffers (for Mongodb)
```

## Toggle showing postgres views in the drawer
If you don't want to see any views in the drawer, add this to vimrc:
This option must be disabled (set to 0) for Redshift.

```vimL
let g:db_ui_use_postgres_views = 0
```

## Disable builtin progress bar
If you want to utilize *DBExecutePre or *DBExecutePost to make your own progress bar
or if you want to disable the progress entirely set to 1.

```vimL
let g:db_ui_disable_progress_bar = 1
```
