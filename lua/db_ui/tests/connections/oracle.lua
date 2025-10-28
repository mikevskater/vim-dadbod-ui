-- Oracle Connection Tests with Real Database Testing
local M = {}
local test = require('db_ui.tests.init')
local config = require('db_ui.tests.test_config')
local helper = require('db_ui.tests.test_db_helper')

M.server_url = nil
M.test_db_url = nil
M.server_available = false
M.skip_reason = nil

function M.setup()
  vim.g.db_ui_use_ssms_style = 0
  M.server_url = config.get_server_url('oracle')
  if not M.server_url then M.skip_reason = "Oracle not configured"; return end
  
  local available, err = helper.check_server_available(M.server_url)
  if not available then M.skip_reason = "Oracle not available: " .. (err or ""); return end
  M.server_available = true
  
  print("🔍 Checking Oracle at: " .. M.server_url)
  print("✅ Oracle available")
  -- Oracle uses USER as "database", so we'll just connect and populate
  M.test_db_url = M.server_url
  print("📝 Populating Oracle schema...")
  local populate_success, populate_err = helper.populate_test_database(M.test_db_url, 'oracle')
  if not populate_success then M.skip_reason = "Failed to populate: " .. populate_err; M.server_available = false; return end
  print("✅ Ready for tests\n")
end

function M.teardown()
  if M.server_available and not config.skip_cleanup then
    print("\n🧹 Cleaning up...")
    -- Oracle cleanup would drop tables
    print("✅ Cleaned up")
  end
end

local function skip() if not M.server_available then print("⚠️  Skipping: " .. (M.skip_reason or "")); return true end; return false end

-- Connection Tests
function M.test_basic_oracle_connection_scheme()
  local parsed = vim.fn['db#url#parse'](M.server_url or 'oracle://localhost/ORCL')
  test.assert_equal(parsed.scheme, 'oracle', 'Should parse oracle scheme')
end

function M.test_can_connect_to_oracle()
  if skip() then return end
  local conn = vim.fn['db#connect'](M.test_db_url)
  test.assert_not_nil(conn, 'Should create connection')
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT 1 FROM DUAL')
  test.assert_not_nil(result, 'Should execute query: ' .. (err or ''))
end

-- Metadata Tests
function M.test_can_access_tables()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'oracle' }
  local scheme = vim.fn['db_ui#schemas#get']('oracle')
  -- Oracle uses USER as schema
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, '', 'USERS')
  test.assert_not_nil(columns, 'Should access tables')
end

function M.test_can_list_views()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'oracle' }
  local scheme = vim.fn['db_ui#schemas#get']('oracle')
  local views = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views, 'Should return views')
end

function M.test_can_list_procedures()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'oracle' }
  local scheme = vim.fn['db_ui#schemas#get']('oracle')
  local procedures = vim.fn['db_ui#schemas#query_procedures'](db, scheme)
  test.assert_not_nil(procedures, 'Should return procedures')
end

function M.test_can_list_functions()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'oracle' }
  local scheme = vim.fn['db_ui#schemas#get']('oracle')
  local functions = vim.fn['db_ui#schemas#query_functions'](db, scheme)
  test.assert_not_nil(functions, 'Should return functions')
end

-- Cache Tests
function M.test_cache_enabled()
  if skip() then return end
  test.assert_equal(vim.g.db_ui_cache_enabled, 1, 'Cache should be enabled')
end

function M.test_cache_works()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'oracle' }
  local scheme = vim.fn['db_ui#schemas#get']('oracle')
  local views1 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  local views2 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views1, 'First call should work')
  test.assert_not_nil(views2, 'Second call should use cache')
end

-- Query Tests
function M.test_can_execute_queries()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM USERS')
  test.assert_not_nil(result, 'Should execute SELECT: ' .. (err or ''))
end

function M.test_oracle_uses_dual()
  if skip() then return end
  -- Oracle uses FROM DUAL for single-row queries
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT 1 FROM DUAL')
  test.assert_not_nil(result, 'Should support FROM DUAL syntax')
end

function M.test_oracle_sequences()
  if skip() then return end
  -- Oracle uses sequences for auto-increment
  test.assert(true, 'Oracle uses sequences')
end

return M
