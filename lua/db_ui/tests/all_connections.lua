-- ============================================================================
-- All Database Connection Types Test Suite
-- ============================================================================
-- Master suite that runs all database-specific connection tests
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

-- Individual connection test modules
local connection_suites = {
  { name = "SQL Server Connections", module = "db_ui.tests.connections.sqlserver" },
  { name = "MySQL/MariaDB Connections", module = "db_ui.tests.connections.mysql" },
  { name = "PostgreSQL Connections", module = "db_ui.tests.connections.postgresql" },
  { name = "SQLite Connections", module = "db_ui.tests.connections.sqlite" },
  { name = "BigQuery Connections", module = "db_ui.tests.connections.bigquery" },
  { name = "Oracle Connections", module = "db_ui.tests.connections.oracle" },
}

--- Run all connection tests
function M.run_all_connection_tests()
  test.reset()
  test.output_buf = nil

  test.log(string.rep("=", 80), "header")
  test.log("All Database Connection Types Test Suite", "header")
  test.log(string.rep("=", 80), "header")
  test.log("")
  test.log("Date: " .. os.date("%Y-%m-%d %H:%M:%S"), "info")
  test.log("")
  test.log("Testing connection support for all database types:", "info")
  test.log("  • SQL Server / Azure SQL", "info")
  test.log("  • MySQL / MariaDB", "info")
  test.log("  • PostgreSQL", "info")
  test.log("  • SQLite", "info")
  test.log("  • Google BigQuery", "info")
  test.log("  • Oracle Database", "info")
  test.log("")

  for _, suite in ipairs(connection_suites) do
    local success, module = pcall(require, suite.module)
    if success then
      test.run_suite(suite.name, module)
    else
      test.log("⚠️  Could not load suite: " .. suite.name, "error")
      test.log("   Error: " .. tostring(module), "error")
      test.log("")
    end
  end

  test.print_summary()
  test.show_output()

  -- Save to file
  local results_dir = vim.fn.stdpath("data") .. "/dadbod_ui"
  vim.fn.mkdir(results_dir, "p")
  local filename = results_dir .. "/connection_tests_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  test.save_results(filename)
end

--- Get list of all connection test suites
function M.get_suites()
  return connection_suites
end

--- Run a specific connection test suite
---@param db_type string Database type: sqlserver, mysql, postgresql, sqlite, bigquery, oracle
function M.run_specific(db_type)
  test.reset()
  test.output_buf = nil

  local suite_map = {
    sqlserver = { name = "SQL Server Connections", module = "db_ui.tests.connections.sqlserver" },
    mysql = { name = "MySQL/MariaDB Connections", module = "db_ui.tests.connections.mysql" },
    postgresql = { name = "PostgreSQL Connections", module = "db_ui.tests.connections.postgresql" },
    sqlite = { name = "SQLite Connections", module = "db_ui.tests.connections.sqlite" },
    bigquery = { name = "BigQuery Connections", module = "db_ui.tests.connections.bigquery" },
    oracle = { name = "Oracle Connections", module = "db_ui.tests.connections.oracle" },
  }

  local suite = suite_map[db_type]
  if not suite then
    print("❌ Unknown database type: " .. db_type)
    print("Available types: sqlserver, mysql, postgresql, sqlite, bigquery, oracle")
    return
  end

  test.log(string.rep("=", 80), "header")
  test.log(suite.name .. " Test Suite", "header")
  test.log(string.rep("=", 80), "header")
  test.log("")

  local success, module = pcall(require, suite.module)
  if success then
    test.run_suite(suite.name, module)
  else
    test.log("❌ Could not load suite: " .. suite.name, "error")
    test.log("   Error: " .. tostring(module), "error")
  end

  test.print_summary()
  test.show_output()

  -- Save to file
  local results_dir = vim.fn.stdpath("data") .. "/dadbod_ui"
  vim.fn.mkdir(results_dir, "p")
  local filename = results_dir .. "/" .. db_type .. "_test_results_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  test.save_results(filename)
end

return M
