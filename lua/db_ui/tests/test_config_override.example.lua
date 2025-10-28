-- ============================================================================
-- User Test Configuration Override (EXAMPLE)
-- ============================================================================
-- Copy this file to ~/.local/share/nvim/dadbod_ui/test_config_override.lua
-- and customize with your local database connection strings
--
-- Windows: C:\Users\<YourName>\AppData\Local\nvim-data\dadbod_ui\test_config_override.lua
-- Linux/Mac: ~/.local/share/nvim/dadbod_ui/test_config_override.lua
-- ============================================================================

return {
  -- Configure your localhost database servers
  localhost_servers = {
    -- SQL Server Examples:
    sqlserver = "sqlserver://sa:YourPassword@localhost",
    -- sqlserver = "sqlserver://localhost\\SQLEXPRESS",  -- Named instance
    -- sqlserver = "sqlserver://localhost",               -- Default instance

    -- MySQL Examples:
    mysql = "mysql://root:password@localhost",
    -- mysql = "mysql://localhost:3306",
    -- mysql = "mysql://localhost",

    -- PostgreSQL Examples:
    postgresql = "postgresql://postgres:password@localhost",
    -- postgresql = "postgres://localhost:5432",
    -- postgresql = "postgresql://localhost",

    -- SQLite (file-based, always works)
    sqlite = "sqlite://./test_dbui.db",

    -- BigQuery (requires authentication and project)
    -- bigquery = "bigquery:my-project-id",
    bigquery = nil,

    -- Oracle Examples:
    -- oracle = "oracle://system:password@localhost:1521/ORCL",
    -- oracle = "oracle://localhost/XE",
    oracle = nil,
  },

  -- Test database name (will be created and destroyed)
  test_db_name = "dbui_test_db",

  -- Skip cleanup (leave test DB for debugging)
  skip_cleanup = false,

  -- Verbose output
  verbose = true,
}
