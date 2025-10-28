-- ============================================================================
-- SQL Parser Tests (Phase 2)
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

function M.setup()
  vim.g.db_ui_enable_intellisense = 1
end

-- ============================================================================
-- Tests
-- ============================================================================

function M.test_parse_database_references_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#parse_database_references'),
    1,
    "parse_database_references should exist"
  )
end

function M.test_parse_simple_external_db_reference()
  local query = "SELECT * FROM OtherDB.dbo.Users"
  local refs = vim.fn['db_ui#completion#parse_database_references'](query)

  test.assert_equal(type(refs), "table", "Should return table of references")
  test.assert_contains(refs, "OtherDB", "Should detect OtherDB")
end

function M.test_parse_multiple_external_db_references()
  local query = "SELECT * FROM MyDB.dbo.Users u JOIN ReportDB.dbo.Orders o ON u.id = o.user_id"
  local refs = vim.fn['db_ui#completion#parse_database_references'](query)

  test.assert(#refs >= 2, "Should detect at least 2 databases")
end

function M.test_does_not_detect_sql_keywords_as_databases()
  local query = "SELECT * FROM Users WHERE id = 1"
  local refs = vim.fn['db_ui#completion#parse_database_references'](query)

  -- Should not include SELECT, FROM, WHERE as databases
  for _, ref in ipairs(refs) do
    test.assert(ref ~= "SELECT", "Should not detect SELECT as database")
    test.assert(ref ~= "FROM", "Should not detect FROM as database")
    test.assert(ref ~= "WHERE", "Should not detect WHERE as database")
  end
end

function M.test_does_not_detect_functions_as_databases()
  local query = "SELECT COUNT(*) FROM Users"
  local refs = vim.fn['db_ui#completion#parse_database_references'](query)

  -- Should not include COUNT as database
  for _, ref in ipairs(refs) do
    test.assert(ref ~= "COUNT", "Should not detect COUNT as database")
  end
end

function M.test_get_cursor_context_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#get_cursor_context'),
    1,
    "get_cursor_context should exist"
  )
end

function M.test_context_detection_with_from_clause()
  -- Create a buffer for testing
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "SELECT * FROM " })

  local line = "SELECT * FROM "
  local col = #line + 1

  local context = vim.fn['db_ui#completion#get_cursor_context'](bufnr, line, col)

  test.assert_not_nil(context, "Should return context")
  test.assert_not_nil(context.type, "Context should have type")

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

function M.test_context_has_required_fields()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local line = "SELECT * FROM Users u WHERE u."
  local col = #line + 1

  local context = vim.fn['db_ui#completion#get_cursor_context'](bufnr, line, col)

  test.assert_not_nil(context.type, "Context should have type field")
  test.assert_not_nil(context.aliases, "Context should have aliases field")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end

function M.test_external_database_fetch_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#fetch_external_database'),
    1,
    "fetch_external_database should exist"
  )
end

function M.test_get_external_completions_function_exists()
  test.assert_equal(
    vim.fn.exists('*db_ui#completion#get_external_completions'),
    1,
    "get_external_completions should exist"
  )
end

return M
