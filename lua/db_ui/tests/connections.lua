-- ============================================================================
-- Database Connection Tests
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

-- ============================================================================
-- Tests
-- ============================================================================

function M.test_db_ui_functions_exist()
  test.assert_equal(vim.fn.exists('*db_ui#open'), 1, "db_ui#open should exist")
  test.assert_equal(vim.fn.exists('*db_ui#toggle'), 1, "db_ui#toggle should exist")
  test.assert_equal(vim.fn.exists('*db_ui#get_conn_info'), 1, "db_ui#get_conn_info should exist")
end

function M.test_db_ui_commands_available()
  local commands = vim.api.nvim_get_commands({})

  test.assert_not_nil(commands.DBUI, "DBUI command should exist")
  test.assert_not_nil(commands.DBUIToggle, "DBUIToggle command should exist")
  test.assert_not_nil(commands.DBUIAddConnection, "DBUIAddConnection command should exist")
end

function M.test_ssms_style_enabled()
  -- Check if SSMS style is configured
  local ssms_enabled = vim.g.db_ui_use_ssms_style

  test.assert_not_nil(ssms_enabled, "SSMS style should be configured")
end

function M.test_cache_enabled()
  local cache_enabled = vim.g.db_ui_cache_enabled

  test.assert_equal(cache_enabled, 1, "Cache should be enabled")
end

function M.test_cache_ttl_configured()
  local cache_ttl = vim.g.db_ui_cache_ttl

  test.assert_not_nil(cache_ttl, "Cache TTL should be configured")
  test.assert(cache_ttl > 0, "Cache TTL should be positive")
end

function M.test_save_location_configured()
  local save_location = vim.g.db_ui_save_location

  test.assert_not_nil(save_location, "Save location should be configured")
end

function M.test_notification_support()
  local use_notify = vim.g.db_ui_use_nvim_notify

  -- Should be configured (true or false)
  test.assert(
    use_notify == true or use_notify == false or use_notify == 1 or use_notify == 0,
    "Notification setting should be boolean/number"
  )
end

return M
