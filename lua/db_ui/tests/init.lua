-- ============================================================================
-- vim-dadbod-ui Test Framework
-- ============================================================================
-- Native Neovim test runner for IntelliSense and database features
-- Runs tests in live Neovim environment with full Lua and buffer access
-- ============================================================================

local M = {}

-- Test results
M.results = {
  total = 0,
  passed = 0,
  failed = 0,
  errors = {},
  tests = {}
}

-- Test output buffer
M.output_buf = nil
M.output_win = nil

-- ============================================================================
-- Test Framework Core
-- ============================================================================

--- Reset test results
function M.reset()
  M.results = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = {},
    tests = {}
  }
end

--- Assert that condition is true
---@param condition boolean
---@param message string
function M.assert(condition, message)
  if not condition then
    error("Assertion failed: " .. (message or "unknown"))
  end
end

--- Assert equality
---@param actual any
---@param expected any
---@param message string
function M.assert_equal(actual, expected, message)
  if actual ~= expected then
    local msg = string.format(
      "%s\nExpected: %s\nActual: %s",
      message or "Values not equal",
      vim.inspect(expected),
      vim.inspect(actual)
    )
    error(msg)
  end
end

--- Assert not nil
---@param value any
---@param message string
function M.assert_not_nil(value, message)
  if value == nil then
    error(message or "Expected non-nil value")
  end
end

--- Assert table contains value
---@param tbl table
---@param value any
---@param message string
function M.assert_contains(tbl, value, message)
  for _, v in ipairs(tbl) do
    if v == value then
      return
    end
  end
  error(message or string.format("Table does not contain: %s", vim.inspect(value)))
end

--- Run a single test
---@param name string
---@param test_fn function
function M.test(name, test_fn)
  M.results.total = M.results.total + 1

  local success, err = pcall(test_fn)

  if success then
    M.results.passed = M.results.passed + 1
    table.insert(M.results.tests, {
      name = name,
      status = "PASS",
      error = nil
    })
  else
    M.results.failed = M.results.failed + 1
    table.insert(M.results.tests, {
      name = name,
      status = "FAIL",
      error = tostring(err)
    })
    table.insert(M.results.errors, {
      test = name,
      error = tostring(err)
    })
  end
end

--- Run a test suite
---@param suite_name string
---@param suite_module table
function M.run_suite(suite_name, suite_module)
  M.log("", "header")
  M.log("Running: " .. suite_name, "header")
  M.log(string.rep("=", 80), "header")
  M.log("")

  local suite_start = M.results.total

  -- Run setup if exists
  if suite_module.setup then
    local success, err = pcall(suite_module.setup)
    if not success then
      M.log("⚠️  Setup failed: " .. tostring(err), "error")
      return
    end
  end

  -- Run tests
  for name, test_fn in pairs(suite_module) do
    if type(test_fn) == "function" and name ~= "setup" and name ~= "teardown" then
      M.test(name, test_fn)
    end
  end

  -- Run teardown if exists
  if suite_module.teardown then
    pcall(suite_module.teardown)
  end

  local suite_total = M.results.total - suite_start
  local suite_passed = 0
  for i = suite_start + 1, M.results.total do
    if M.results.tests[i].status == "PASS" then
      suite_passed = suite_passed + 1
    end
  end

  M.log("")
  M.log(string.format("Suite: %d/%d passed", suite_passed, suite_total), "info")
  M.log("")
end

-- ============================================================================
-- Output Management
-- ============================================================================

--- Log message to output buffer
---@param message string
---@param level string|nil
function M.log(message, level)
  level = level or "info"

  -- Create output buffer if needed
  if not M.output_buf or not vim.api.nvim_buf_is_valid(M.output_buf) then
    M.output_buf = vim.api.nvim_create_buf(false, true)

    -- Try to set name, but don't fail if it already exists
    local success, err = pcall(vim.api.nvim_buf_set_name, M.output_buf, "DBUI Test Results")
    if not success then
      -- Buffer name exists, just use a unique name
      vim.api.nvim_buf_set_name(M.output_buf, "DBUI Test Results " .. os.time())
    end

    vim.bo[M.output_buf].filetype = "dbui-test-results"
    -- Make buffer modifiable
    vim.bo[M.output_buf].modifiable = true
  end

  -- Split message by newlines if it contains any
  local lines_to_add = vim.split(message, '\n', { plain = true })

  -- Get current line count
  local line_count = vim.api.nvim_buf_line_count(M.output_buf)

  -- If buffer is empty (has one empty line), start from line 0
  local existing_lines = vim.api.nvim_buf_get_lines(M.output_buf, 0, -1, false)
  if line_count == 1 and existing_lines[1] == "" then
    line_count = 0
  end

  -- Append lines
  vim.api.nvim_buf_set_lines(M.output_buf, line_count, -1, false, lines_to_add)
end

--- Show output buffer
function M.show_output()
  if not M.output_buf or not vim.api.nvim_buf_is_valid(M.output_buf) then
    return
  end

  -- Create or reuse window
  if not M.output_win or not vim.api.nvim_win_is_valid(M.output_win) then
    vim.cmd('botright vsplit')
    M.output_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.output_win, M.output_buf)
  else
    vim.api.nvim_set_current_win(M.output_win)
  end

  -- Set buffer options (keep modifiable for now)
  vim.bo[M.output_buf].buftype = 'nofile'
  vim.wo[M.output_win].number = false
  vim.wo[M.output_win].relativenumber = false

  -- Scroll to bottom
  local line_count = vim.api.nvim_buf_line_count(M.output_buf)
  if line_count > 0 then
    vim.api.nvim_win_set_cursor(M.output_win, {line_count, 0})
  end
end

--- Save results to file
---@param filename string
function M.save_results(filename)
  if not M.output_buf or not vim.api.nvim_buf_is_valid(M.output_buf) then
    print("❌ No test results to save")
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.output_buf, 0, -1, false)
  local file = io.open(filename, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:write("\n")  -- Add final newline
    file:close()
    print("✅ Results saved to: " .. filename)
  else
    print("❌ Failed to save results to: " .. filename)
  end
end

--- Print summary
function M.print_summary()
  M.log("")
  M.log(string.rep("=", 80), "header")
  M.log("TEST SUMMARY", "header")
  M.log(string.rep("=", 80), "header")
  M.log("")
  M.log(string.format("Total:  %d", M.results.total), "info")
  M.log(string.format("Passed: %d ✅", M.results.passed), "success")
  M.log(string.format("Failed: %d ❌", M.results.failed), "error")
  M.log("")

  if M.results.failed > 0 then
    M.log("FAILED TESTS:", "error")
    M.log(string.rep("-", 80), "error")
    for _, test in ipairs(M.results.tests) do
      if test.status == "FAIL" then
        M.log(string.format("  ❌ %s", test.name), "error")
        if test.error then
          M.log(string.format("     %s", test.error), "error")
        end
      end
    end
    M.log("")
  end

  local success_rate = M.results.total > 0 and
    math.floor((M.results.passed / M.results.total) * 100) or 0
  M.log(string.format("Success Rate: %d%%", success_rate), "info")
  M.log("")
end

-- ============================================================================
-- Test Suite Loaders
-- ============================================================================

--- Run all tests
function M.run_all()
  M.reset()
  M.output_buf = nil

  M.log(string.rep("=", 80), "header")
  M.log("vim-dadbod-ui Full Test Suite", "header")
  M.log(string.rep("=", 80), "header")
  M.log("")
  M.log("Date: " .. os.date("%Y-%m-%d %H:%M:%S"), "info")
  M.log("")

  -- Load and run test suites
  local suites = {
    { name = "Database Connections", module = "db_ui.tests.connections" },
    { name = "SSMS Features", module = "db_ui.tests.ssms_features" },
    { name = "IntelliSense Cache", module = "db_ui.tests.intellisense_cache" },
    { name = "SQL Parser", module = "db_ui.tests.sql_parser" },
    { name = "blink.cmp Integration", module = "db_ui.tests.blink_integration" },
  }

  for _, suite in ipairs(suites) do
    local success, module = pcall(require, suite.module)
    if success then
      M.run_suite(suite.name, module)
    else
      M.log("⚠️  Could not load suite: " .. suite.name, "error")
      M.log("   Error: " .. tostring(module), "error")
      M.log("")
    end
  end

  M.print_summary()
  M.show_output()

  -- Save to file
  local results_dir = vim.fn.stdpath("data") .. "/dadbod_ui"
  vim.fn.mkdir(results_dir, "p")
  local filename = results_dir .. "/test_results_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  M.save_results(filename)
end

--- Run IntelliSense tests only
function M.run_intellisense()
  M.reset()
  M.output_buf = nil

  M.log(string.rep("=", 80), "header")
  M.log("IntelliSense Test Suite", "header")
  M.log(string.rep("=", 80), "header")
  M.log("")

  local suites = {
    { name = "IntelliSense Cache", module = "db_ui.tests.intellisense_cache" },
    { name = "SQL Parser", module = "db_ui.tests.sql_parser" },
    { name = "blink.cmp Integration", module = "db_ui.tests.blink_integration" },
  }

  for _, suite in ipairs(suites) do
    local success, module = pcall(require, suite.module)
    if success then
      M.run_suite(suite.name, module)
    else
      M.log("⚠️  Could not load suite: " .. suite.name, "error")
    end
  end

  M.print_summary()
  M.show_output()

  local results_dir = vim.fn.stdpath("data") .. "/dadbod_ui"
  vim.fn.mkdir(results_dir, "p")
  local filename = results_dir .. "/intellisense_test_results_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  M.save_results(filename)
end

--- Run connection tests only
function M.run_connections()
  M.reset()
  M.output_buf = nil

  M.log(string.rep("=", 80), "header")
  M.log("Database Connection Test Suite", "header")
  M.log(string.rep("=", 80), "header")
  M.log("")

  local success, module = pcall(require, "db_ui.tests.connections")
  if success then
    M.run_suite("Database Connections", module)
  else
    M.log("❌ Could not load connection tests", "error")
  end

  M.print_summary()
  M.show_output()

  local results_dir = vim.fn.stdpath("data") .. "/dadbod_ui"
  vim.fn.mkdir(results_dir, "p")
  local filename = results_dir .. "/connection_test_results_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  M.save_results(filename)
end

return M
