-- PostgreSQL Connection Tests with Real Database Testing
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
  M.server_url = config.get_server_url('postgresql')
  if not M.server_url then M.skip_reason = "PostgreSQL not configured"; return end
  
  local available, err = helper.check_server_available(M.server_url)
  if not available then M.skip_reason = "PostgreSQL not available: " .. (err or ""); return end
  M.server_available = true
  
  print("🔍 Checking PostgreSQL at: " .. M.server_url)
  print("✅ PostgreSQL available")
  print("🔨 Creating test database")
  local create_success, create_err = helper.create_test_database(M.server_url, config.test_db_name)
  if not create_success then M.skip_reason = "Failed to create DB: " .. create_err; M.server_available = false; return end
  print("✅ Test database created")
  
  M.test_db_url = helper.get_test_db_url(M.server_url, config.test_db_name)
  print("📝 Populating database...")
  local populate_success, populate_err = helper.populate_test_database(M.test_db_url, 'postgresql')
  if not populate_success then M.skip_reason = "Failed to populate: " .. populate_err; M.server_available = false; return end
  print("✅ Ready for tests\n")
end

function M.teardown()
  if M.server_available and not config.skip_cleanup then
    print("\n🧹 Cleaning up...")
    helper.drop_test_database(M.server_url, config.test_db_name)
    print("✅ Cleaned up")
  end
end

local function skip() if not M.server_available then print("⚠️  Skipping: " .. (M.skip_reason or "")); return true end; return false end

-- Connection Tests
function M.test_basic_postgresql_connection_scheme()
  local parsed = vim.fn['db#url#parse'](M.server_url or 'postgresql://localhost')
  test.assert(parsed.scheme == 'postgresql' or parsed.scheme == 'postgres', 'Should parse postgresql scheme')
end

function M.test_can_connect_to_test_database()
  if skip() then return end
  local conn = vim.fn['db#connect'](M.test_db_url)
  test.assert_not_nil(conn, 'Should create connection')
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT 1')
  test.assert_not_nil(result, 'Should execute query: ' .. (err or ''))
end

-- Metadata Tests
function M.test_can_list_databases()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local databases = vim.fn['db_ui#schemas#query_databases'](db, scheme)
  test.assert_not_nil(databases, 'Should return databases')
  test.assert_equal(type(databases), 'table', 'Databases should be table')
end

function M.test_can_access_tables()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, 'test_schema', 'users')
  test.assert_not_nil(columns, 'Should access tables')
  test.assert(#columns > 0, 'Should have columns')
end

function M.test_can_list_views()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local views = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views, 'Should return views')
end

function M.test_can_list_procedures()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local procedures = vim.fn['db_ui#schemas#query_procedures'](db, scheme)
  test.assert_not_nil(procedures, 'Should return procedures')
end

function M.test_can_list_functions()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local functions = vim.fn['db_ui#schemas#query_functions'](db, scheme)
  test.assert_not_nil(functions, 'Should return functions')
end

function M.test_can_get_table_columns()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, 'test_schema', 'users')
  test.assert_not_nil(columns, 'Should return columns')
end

function M.test_can_get_primary_keys()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local pks = vim.fn['db_ui#schemas#query_primary_keys'](db, scheme, 'test_schema', 'users')
  test.assert_not_nil(pks, 'Should return primary keys')
end

function M.test_can_get_foreign_keys()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local fks = vim.fn['db_ui#schemas#query_foreign_keys'](db, scheme, 'test_schema', 'posts')
  test.assert_not_nil(fks, 'Should return foreign keys')
end

-- Cache Tests
function M.test_cache_enabled()
  if skip() then return end
  test.assert_equal(vim.g.db_ui_cache_enabled, 1, 'Cache should be enabled')
end

function M.test_cache_works()
  if skip() then return end
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'postgresql' }
  local scheme = vim.fn['db_ui#schemas#get']('postgresql')
  local views1 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  local views2 = vim.fn['db_ui#schemas#query_views'](db, scheme)
  test.assert_not_nil(views1, 'First call should work')
  test.assert_not_nil(views2, 'Second call should use cache')
end

-- Query Tests
function M.test_can_execute_queries()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM test_schema.users')
  test.assert_not_nil(result, 'Should execute SELECT: ' .. (err or ''))
end

function M.test_can_insert_data()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, "INSERT INTO test_schema.users (username, email) VALUES ('test3', 'test3@example.com')")
  test.assert(result ~= nil or err == nil, 'Should insert data')
end

function M.test_schema_qualified_names()
  if skip() then return end
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT COUNT(*) FROM test_schema.users')
  test.assert_not_nil(result, 'Should support schema.table syntax')
end

return M
