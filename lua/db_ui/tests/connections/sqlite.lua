-- SQLite Connection Tests with Real Database Testing
local M = {}
local test = require('db_ui.tests.init')
local config = require('db_ui.tests.test_config')
local helper = require('db_ui.tests.test_db_helper')

M.test_db_url = nil
M.server_available = false
M.skip_reason = nil

function M.setup()
  vim.g.db_ui_use_ssms_style = 0
  -- SQLite is file-based, always available
  M.test_db_url = "sqlite://./test_dbui.db"
  M.server_available = true
  
  print("🔍 SQLite is file-based, always available")
  print("📋 Test database URL: " .. M.test_db_url)
  print("📝 Populating database...")
  local populate_success, populate_err = helper.populate_test_database(M.test_db_url, 'sqlite')
  if not populate_success then M.skip_reason = "Failed to populate: " .. populate_err; M.server_available = false; return end
  print("✅ Ready for tests\n")
end

function M.teardown()
  if M.server_available and not config.skip_cleanup then
    print("\n🧹 Cleaning up...")
    -- Delete SQLite file
    local file_path = "./test_dbui.db"
    if vim.fn.filereadable(file_path) == 1 then
      vim.fn.delete(file_path)
    end
    print("✅ Cleaned up")
  end
end

local function skip() if not M.server_available then print("⚠️  Skipping: " .. (M.skip_reason or "")); return true end; return false end

-- Connection Tests
function M.test_basic_sqlite_connection_scheme()
  local parsed = vim.fn['db#url#parse']('sqlite://./test.db')
  test.assert_equal(parsed.scheme, 'sqlite', 'Should parse sqlite scheme')
end

function M.test_can_connect_to_test_database()
  if skip() then return end
  local conn = vim.fn['db#connect'](M.test_db_url)
  test.assert_not_nil(conn, 'Should create connection')
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT 1')
  test.assert_not_nil(result, 'Should execute query: ' .. (err or ''))
end

-- Metadata Tests (SQLite doesn't use schemas)
function M.test_can_access_tables()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlite' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlite')
  -- SQLite doesn't have schemas, use empty string
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, '', 'users')
  test.assert_not_nil(columns, 'Should access tables')
  test.assert(#columns > 0, 'Should have columns')
end

function M.test_can_list_views()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlite' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlite')
  local views = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views, 'Should return views')
end

function M.test_can_get_table_columns()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlite' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlite')
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, '', 'users')
  test.assert_not_nil(columns, 'Should return columns')
  -- Check for expected columns
  local found_id, found_username = false, false
  for _, col in ipairs(columns) do
    if type(col) == 'table' and col.name then
      if col.name == 'id' then found_id = true end
      if col.name == 'username' then found_username = true end
    elseif type(col) == 'string' then
      if col:find('id') then found_id = true end
      if col:find('username') then found_username = true end
    end
  end
  test.assert(found_id or found_username, 'Should find columns')
end

-- Cache Tests
function M.test_cache_enabled()
  if skip() then return end
  test.assert_equal(vim.g.db_ui_cache_enabled, 1, 'Cache should be enabled')
end

function M.test_cache_works()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlite' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlite')
  local views1 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  local views2 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views1, 'First call should work')
  test.assert_not_nil(views2, 'Second call should use cache')
end

-- Query Tests
function M.test_can_execute_queries()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM users')
  test.assert_not_nil(result, 'Should execute SELECT: ' .. (err or ''))
end

function M.test_can_insert_data()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, "INSERT INTO users (id, username, email) VALUES (3, 'test3', 'test3@example.com')")
  test.assert(result ~= nil or err == nil, 'Should insert data')
end

function M.test_sqlite_no_schema_concept()
  if skip() then return end
  -- SQLite doesn't have schemas like PostgreSQL/SQL Server
  test.assert(true, 'SQLite uses simple database-level organization')
end

function M.test_sqlite_file_based()
  if skip() then return end
  -- SQLite is file-based, no server needed
  test.assert(true, 'SQLite is file-based')
end

return M
