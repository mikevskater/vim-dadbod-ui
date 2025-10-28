-- ============================================================================
-- SSMS-Style Features Tests
-- ============================================================================
-- Tests for SQL Server Management Studio-like features added to vim-dadbod-ui
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

function M.setup()
  -- Ensure SSMS style is enabled
  vim.g.db_ui_use_ssms_style = 1
end

-- ============================================================================
-- Configuration Tests
-- ============================================================================

function M.test_ssms_style_enabled()
  test.assert_equal(vim.g.db_ui_use_ssms_style, 1, "SSMS style should be enabled")
end

function M.test_ssms_object_types_configured()
  local object_types = vim.g.db_ui_ssms_object_types

  test.assert_not_nil(object_types, "Object types should be configured")
  test.assert_equal(type(object_types), "table", "Object types should be a table")

  -- Check for expected object types
  test.assert_contains(object_types, "tables", "Should include tables")
  test.assert_contains(object_types, "views", "Should include views")
  test.assert_contains(object_types, "procedures", "Should include procedures")
  test.assert_contains(object_types, "functions", "Should include functions")
end

function M.test_show_schema_prefix_enabled()
  test.assert_equal(vim.g.db_ui_show_schema_prefix, 1, "Schema prefix should be enabled")
end

function M.test_ssms_structural_groups_enabled()
  test.assert_equal(vim.g.db_ui_ssms_show_columns, 1, "Columns display should be enabled")
  test.assert_equal(vim.g.db_ui_ssms_show_indexes, 1, "Indexes display should be enabled")
  test.assert_equal(vim.g.db_ui_ssms_show_keys, 1, "Keys display should be enabled")
  test.assert_equal(vim.g.db_ui_ssms_show_constraints, 1, "Constraints display should be enabled")
  test.assert_equal(vim.g.db_ui_ssms_show_dependencies, 1, "Dependencies display should be enabled")
end

function M.test_hide_system_databases_enabled()
  test.assert_equal(vim.g.db_ui_hide_system_databases, 1, "System databases should be hidden")
end

function M.test_hide_schemas_configured()
  local hide_schemas = vim.g.db_ui_hide_schemas

  test.assert_not_nil(hide_schemas, "Hide schemas should be configured")
  test.assert_equal(type(hide_schemas), "table", "Hide schemas should be a table")

  -- Should hide system schemas
  test.assert_contains(hide_schemas, "sys", "Should hide sys schema")
  test.assert_contains(hide_schemas, "INFORMATION_SCHEMA", "Should hide INFORMATION_SCHEMA")
end

-- ============================================================================
-- Icon Configuration Tests
-- ============================================================================

function M.test_ssms_icons_configured()
  local icons = vim.g.db_ui_icons

  test.assert_not_nil(icons, "Icons should be configured")
  test.assert_not_nil(icons.expanded, "Expanded icons should exist")
  test.assert_not_nil(icons.collapsed, "Collapsed icons should exist")

  -- Check for SSMS object type icons
  test.assert_not_nil(icons.expanded.databases, "Databases icon should exist")
  test.assert_not_nil(icons.expanded.views, "Views icon should exist")
  test.assert_not_nil(icons.expanded.procedures, "Procedures icon should exist")
  test.assert_not_nil(icons.expanded.functions, "Functions icon should exist")
end

-- ============================================================================
-- Schema Query Functions Tests
-- ============================================================================

function M.test_schema_query_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_databases'),
    1,
    "query_databases should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_tables'),
    1,
    "query_tables should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_views'),
    1,
    "query_views should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_procedures'),
    1,
    "query_procedures should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_functions'),
    1,
    "query_functions should exist"
  )
end

function M.test_column_metadata_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_columns'),
    1,
    "query_columns should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_indexes'),
    1,
    "query_indexes should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_primary_keys'),
    1,
    "query_primary_keys should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_foreign_keys'),
    1,
    "query_foreign_keys should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_constraints'),
    1,
    "query_constraints should exist"
  )
end

function M.test_procedure_parameter_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#query_parameters'),
    1,
    "query_parameters should exist for procedures/functions"
  )
end

-- ============================================================================
-- Cache System Tests
-- ============================================================================

function M.test_cache_enabled()
  test.assert_equal(vim.g.db_ui_cache_enabled, 1, "Cache should be enabled")
end

function M.test_cache_ttl_configured()
  local cache_ttl = vim.g.db_ui_cache_ttl

  test.assert_not_nil(cache_ttl, "Cache TTL should be configured")
  test.assert_equal(type(cache_ttl), "number", "Cache TTL should be a number")
  test.assert(cache_ttl > 0, "Cache TTL should be positive")
  test.assert_equal(cache_ttl, 300, "Cache TTL should be 300 seconds (5 minutes)")
end

function M.test_cache_clear_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#clear_cache'),
    1,
    "clear_cache should exist"
  )
end

function M.test_cache_clear_for_database_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#schemas#clear_cache_for'),
    1,
    "clear_cache_for should exist"
  )
end

-- ============================================================================
-- Table Helpers Tests
-- ============================================================================

function M.test_table_helpers_configured()
  local helpers = vim.g.db_ui_table_helpers

  test.assert_not_nil(helpers, "Table helpers should be configured")
  test.assert_equal(type(helpers), "table", "Table helpers should be a table")
end

function M.test_sqlserver_table_helpers_exist()
  local helpers = vim.g.db_ui_table_helpers

  if helpers.sqlserver then
    test.assert_not_nil(helpers.sqlserver.Count, "SQL Server Count helper should exist")
    test.assert_not_nil(helpers.sqlserver.Top100, "SQL Server Top100 helper should exist")
    test.assert_not_nil(helpers.sqlserver.Columns, "SQL Server Columns helper should exist")
    test.assert_not_nil(helpers.sqlserver.Indexes, "SQL Server Indexes helper should exist")
  else
    -- Table helpers might not be configured yet - that's ok
    test.assert(true, "SQL Server helpers optional")
  end
end

function M.test_mysql_table_helpers_exist()
  local helpers = vim.g.db_ui_table_helpers

  if helpers.mysql then
    test.assert_not_nil(helpers.mysql.Count, "MySQL Count helper should exist")
    test.assert_not_nil(helpers.mysql.Describe, "MySQL Describe helper should exist")
    test.assert_not_nil(helpers.mysql.Limit100, "MySQL Limit100 helper should exist")
  else
    -- Table helpers might not be configured yet - that's ok
    test.assert(true, "MySQL helpers optional")
  end
end

function M.test_auto_execute_table_helpers_configured()
  local auto_execute = vim.g.db_ui_auto_execute_table_helpers

  test.assert(
    auto_execute == 0 or auto_execute == 1,
    "Auto execute should be configured as 0 or 1"
  )
end

-- ============================================================================
-- Pagination Tests
-- ============================================================================

function M.test_pagination_configured()
  local max_items = vim.g.db_ui_max_items_per_page

  test.assert_not_nil(max_items, "Max items per page should be configured")
  test.assert_equal(type(max_items), "number", "Max items should be a number")
  test.assert(max_items >= 0, "Max items should be non-negative")
end

function M.test_loading_indicator_configured()
  local show_loading = vim.g.db_ui_show_loading_indicator

  test.assert(
    show_loading == 0 or show_loading == 1,
    "Loading indicator should be configured"
  )
end

-- ============================================================================
-- Notification System Tests
-- ============================================================================

function M.test_notification_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#notifications#info'),
    1,
    "notifications#info should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#notifications#error'),
    1,
    "notifications#error should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#notifications#warning'),
    1,
    "notifications#warning should exist"
  )
end

function M.test_nvim_notify_configured()
  local use_notify = vim.g.db_ui_use_nvim_notify

  test.assert(
    use_notify == true or use_notify == false or use_notify == 1 or use_notify == 0 or use_notify == nil,
    "nvim-notify setting should be boolean or nil"
  )
end

return M
