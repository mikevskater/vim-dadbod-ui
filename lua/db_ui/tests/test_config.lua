-- ============================================================================
-- Database Test Configuration
-- ============================================================================
-- Configure localhost database servers for testing
-- Copy this file and customize with your local database connection strings
-- ============================================================================

local M = {}

-- ============================================================================
-- Localhost Connection Configuration
-- ============================================================================

--- Configure your localhost database servers here
--- Set to nil or empty string to skip testing that database type
M.localhost_servers = {
  -- SQL Server
  -- Examples:
  --   "sqlserver://localhost"                    -- Default instance
  --   "sqlserver://localhost\\SQLEXPRESS"        -- Named instance
  --   "sqlserver://sa:YourPassword@localhost"    -- With credentials
  sqlserver = "sqlserver://localhost",

  -- MySQL / MariaDB
  -- Examples:
  --   "mysql://localhost"
  --   "mysql://root:password@localhost"
  --   "mysql://localhost:3306"
  mysql = nil,

  -- PostgreSQL
  -- Examples:
  --   "postgresql://localhost"
  --   "postgresql://postgres:password@localhost"
  --   "postgres://localhost:5432"
  postgresql = nil,

  -- SQLite (file-based, always available)
  -- Examples:
  --   "sqlite:///tmp/test.db"
  --   "sqlite://./test.db"
  sqlite = "sqlite://./test_dbui.db",  -- Default: always test SQLite

  -- Google BigQuery (requires authentication)
  -- Examples:
  --   "bigquery:my-project"
  --   "bigquery:my-project/my_dataset"
  bigquery = nil,

  -- Oracle Database
  -- Examples:
  --   "oracle://localhost/ORCL"
  --   "oracle://user:pass@localhost:1521/ORCL"
  --   "oracle://TNSNAME"
  oracle = nil,
}

-- ============================================================================
-- Test Database Configuration
-- ============================================================================

--- Test database name (will be created and destroyed during tests)
M.test_db_name = "dbui_test_db"

--- Whether to skip cleanup (leave test database for debugging)
M.skip_cleanup = false

--- Verbose output during test database setup
M.verbose = false

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Get configured server URL for a database type
---@param db_type string Database type (sqlserver, mysql, postgresql, etc.)
---@return string|nil url Server URL or nil if not configured
function M.get_server_url(db_type)
  return M.localhost_servers[db_type]
end

--- Check if a database type is configured for testing
---@param db_type string Database type
---@return boolean configured True if server URL is configured
function M.is_configured(db_type)
  local url = M.get_server_url(db_type)
  return url ~= nil and url ~= ""
end

--- Get all configured database types
---@return table db_types Array of configured database type names
function M.get_configured_types()
  local types = {}
  for db_type, url in pairs(M.localhost_servers) do
    if url and url ~= "" then
      table.insert(types, db_type)
    end
  end
  return types
end

--- Print configuration status
function M.print_status()
  print("Database Test Configuration Status:")
  print(string.rep("=", 60))
  print("")
  print("Config file: " .. M.get_user_config_path())
  print("")

  for db_type, url in pairs(M.localhost_servers) do
    local status = url and "✅ Configured" or "❌ Not configured"
    print(string.format("  %-15s %s", db_type, status))
    if url and M.verbose then
      print(string.format("    URL: %s", url))
    end
  end

  print("")
  print(string.format("Test DB Name: %s", M.test_db_name))
  print(string.format("Skip Cleanup: %s", M.skip_cleanup))
  print(string.format("Verbose: %s", M.verbose))
  print("")
  print(string.rep("=", 60))
  print("Commands:")
  print("  :DBUITestConfig          - Edit configuration")
  print("  :DBUITestConfigReload    - Reload after editing")
  print("  :DBUITestConfigStatus    - Show this status")
  print(string.rep("=", 60))
end

-- ============================================================================
-- User Configuration Override
-- ============================================================================

--- Get path to user config file
---@return string path Path to user config override file
function M.get_user_config_path()
  local data_dir = vim.fn.stdpath("data")
  return data_dir .. "/dadbod_ui/test_config_override.lua"
end

--- Create default user config file if it doesn't exist
function M.create_default_config()
  local config_path = M.get_user_config_path()
  local config_dir = vim.fn.fnamemodify(config_path, ":h")

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(config_dir) == 0 then
    vim.fn.mkdir(config_dir, "p")
  end

  -- Don't overwrite existing config
  if vim.fn.filereadable(config_path) == 1 then
    print("⚠️  Config file already exists: " .. config_path)
    print("   Edit it to configure your database connections")
    return config_path
  end

  -- Create default config file
  local default_config = [[-- ============================================================================
-- Database Test Configuration
-- ============================================================================
-- Configure your localhost database servers for testing
-- ============================================================================

return {
  -- Configure your localhost database servers
  -- Set to nil or comment out databases you don't have installed
  localhost_servers = {
    -- SQL Server
    -- Examples:
    --   sqlserver = "sqlserver://sa:YourPassword@localhost"
    --   sqlserver = "sqlserver://localhost\\SQLEXPRESS"
    sqlserver = nil,  -- Set your connection string here

    -- MySQL / MariaDB
    -- Examples:
    --   mysql = "mysql://root:password@localhost"
    --   mysql = "mysql://localhost:3306"
    mysql = nil,  -- Set your connection string here

    -- PostgreSQL
    -- Examples:
    --   postgresql = "postgresql://postgres:password@localhost"
    --   postgresql = "postgres://localhost:5432"
    postgresql = nil,  -- Set your connection string here

    -- SQLite (file-based, always works - no server needed!)
    sqlite = "sqlite://./test_dbui.db",  -- Default: always test SQLite

    -- Google BigQuery (requires authentication)
    -- Examples:
    --   bigquery = "bigquery:my-project-id"
    bigquery = nil,

    -- Oracle Database
    -- Examples:
    --   oracle = "oracle://system:password@localhost:1521/ORCL"
    oracle = nil,
  },

  -- Test database name (will be created and destroyed automatically)
  test_db_name = "dbui_test_db",

  -- Skip cleanup (set to true to keep test DB for debugging)
  skip_cleanup = false,

  -- Verbose output during test database setup
  verbose = true,
}
]]

  -- Write default config
  local file = io.open(config_path, "w")
  if file then
    file:write(default_config)
    file:close()
    print("✅ Created default test config: " .. config_path)
    print("   Edit this file to configure your database connections")
    return config_path
  else
    print("❌ Failed to create config file: " .. config_path)
    return nil
  end
end

--- Try to load user configuration from external file
--- This allows users to configure without modifying the plugin
local function load_user_config()
  -- Try to load from Neovim data directory
  local user_config_path = M.get_user_config_path()

  -- Auto-create default config if it doesn't exist
  if vim.fn.filereadable(user_config_path) == 0 then
    if M.verbose then
      print("ℹ️  No test config found, creating default at: " .. user_config_path)
    end
    M.create_default_config()
  end

  -- Load config
  if vim.fn.filereadable(user_config_path) == 1 then
    local success, user_config = pcall(dofile, user_config_path)
    if success and type(user_config) == "table" then
      -- Merge user configuration
      if user_config.localhost_servers then
        M.localhost_servers = vim.tbl_extend("force", M.localhost_servers, user_config.localhost_servers)
      end
      if user_config.test_db_name then
        M.test_db_name = user_config.test_db_name
      end
      if user_config.skip_cleanup ~= nil then
        M.skip_cleanup = user_config.skip_cleanup
      end
      if user_config.verbose ~= nil then
        M.verbose = user_config.verbose
      end

      if M.verbose then
        print("✅ Loaded user test configuration from: " .. user_config_path)
      end
    end
  end
end

--- Reload configuration from file
function M.reload_config()
  -- Reset to defaults first
  M.localhost_servers = {
    sqlserver = nil,
    mysql = nil,
    postgresql = nil,
    sqlite = "sqlite://./test_dbui.db",
    bigquery = nil,
    oracle = nil,
  }
  M.test_db_name = "dbui_test_db"
  M.skip_cleanup = false
  M.verbose = false

  -- Reload user config
  load_user_config()

  print("✅ Configuration reloaded")
end

--- Open user config file in editor
function M.edit_config()
  local config_path = M.get_user_config_path()

  -- Create if doesn't exist
  if vim.fn.filereadable(config_path) == 0 then
    M.create_default_config()
  end

  -- Open in editor
  vim.cmd('edit ' .. vim.fn.fnameescape(config_path))

  -- Show reminder to reload after editing
  print("💡 After editing, run :DBUITestConfigReload to apply changes")
end

-- Load user config on module load
load_user_config()

return M
