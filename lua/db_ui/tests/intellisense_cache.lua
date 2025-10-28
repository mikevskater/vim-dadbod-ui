-- ============================================================================
-- IntelliSense Cache Tests
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

function M.setup()
  -- Enable IntelliSense for tests
  vim.g.db_ui_enable_intellisense = 1
end

function M.teardown()
  -- Clean up
  if vim.fn.exists('*db_ui#completion#clear_all_caches') == 1 then
    vim.fn['db_ui#completion#clear_all_caches']()
  end
end

-- ============================================================================
-- Tests
-- ============================================================================

function M.test_intellisense_is_enabled()
  test.assert_equal(vim.g.db_ui_enable_intellisense, 1, "IntelliSense should be enabled")
end

function M.test_completion_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#is_available'),
    1,
    "db_ui#completion#is_available should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#completion#init_cache'),
    1,
    "db_ui#completion#init_cache should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#completion#get_completions'),
    1,
    "db_ui#completion#get_completions should exist"
  )
end

function M.test_cache_clear_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#clear_all_caches'),
    1,
    "db_ui#completion#clear_all_caches should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#completion#refresh_cache'),
    1,
    "db_ui#completion#refresh_cache should exist"
  )
end

function M.test_context_detection_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#get_cursor_context'),
    1,
    "db_ui#completion#get_cursor_context should exist"
  )
end

function M.test_external_database_functions_exist()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#parse_database_references'),
    1,
    "db_ui#completion#parse_database_references should exist"
  )

  test.assert_equal(
    vim.fn.exists('*db_ui#completion#fetch_external_database'),
    1,
    "db_ui#completion#fetch_external_database should exist"
  )
end

function M.test_cache_commands_available()
  -- Check if commands are defined
  local commands = vim.api.nvim_get_commands({})

  test.assert_not_nil(commands.DBUIRefreshCompletion, "DBUIRefreshCompletion command should exist")
  test.assert_not_nil(commands.DBUIRefreshCompletionAll, "DBUIRefreshCompletionAll command should exist")
  test.assert_not_nil(commands.DBUICompletionStatus, "DBUICompletionStatus command should exist")
end

function M.test_intellisense_availability_check()
  -- This should work even without a database connection
  local available = vim.fn['db_ui#completion#is_available']()

  -- Should return 0 or 1
  test.assert(
    available == 0 or available == 1,
    "is_available should return 0 or 1"
  )
end

function M.test_clear_all_caches_doesnt_error()
  -- This should not error even with no caches
  local success = pcall(vim.fn['db_ui#completion#clear_all_caches'])
  test.assert(success, "clear_all_caches should not error")
end

return M
