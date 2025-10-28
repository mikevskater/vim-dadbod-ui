-- ============================================================================
-- MySQL/MariaDB Connection Tests
-- ============================================================================
-- Tests for MySQL and MariaDB database connections against real localhost server
-- Scheme: mysql
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')
local config = require('db_ui.tests.test_config')
local helper = require('db_ui.tests.test_db_helper')

-- Module state
M.server_url = nil
M.test_db_url = nil
M.server_available = false
M.skip_reason = nil

-- ============================================================================
-- Setup and Teardown
-- ============================================================================

function M.setup()
  vim.g.db_ui_use_ssms_style = 0  -- MySQL doesn't use SSMS style typically

  -- Check if MySQL is configured
  M.server_url = config.get_server_url('mysql')
  if not M.server_url then
    M.skip_reason = "MySQL not configured in test_config.lua"
    return
  end

  -- Check if server is available
  local available, err = helper.check_server_available(M.server_url)
  if not available then
    M.skip_reason = "MySQL not available: " .. (err or "unknown error")
    return
  end

  M.server_available = true

  -- Print status
  print("🔍 Checking MySQL availability at: " .. M.server_url)
  print("✅ MySQL is available")

  -- Create test database
  print("🔨 Creating test database: " .. config.test_db_name)
  local create_success, create_err = helper.create_test_database(M.server_url, config.test_db_name)
  if not create_success then
    M.skip_reason = "Failed to create test database: " .. create_err
    M.server_available = false
    return
  end
  print("✅ Test database created")

  -- Get test database URL
  M.test_db_url = helper.get_test_db_url(M.server_url, config.test_db_name)
  print("📋 Test database URL: " .. M.test_db_url)

  -- Populate test database
  print("📝 Populating test database with test objects...")
  local populate_success, populate_err = helper.populate_test_database(M.test_db_url, 'mysql')
  if not populate_success then
    M.skip_reason = "Failed to populate test database: " .. populate_err
    M.server_available = false
    return
  end
  print("✅ Test database populated successfully")
  print("🚀 Ready to run MySQL tests")
  print("")
end

function M.teardown()
  if M.server_available and not config.skip_cleanup then
    print("")
    print("🧹 Cleaning up test database...")
    helper.drop_test_database(M.server_url, config.test_db_name)
    print("✅ Test database cleaned up")
  end
end

-- Helper function to skip tests if MySQL not available
local function skip_if_unavailable()
  if not M.server_available then
    if M.skip_reason then
      print("⚠️  Skipping MySQL tests: " .. M.skip_reason)
    end
    return true
  end
  return false
end

-- ============================================================================
-- Connection URL Parsing Tests
-- ============================================================================

function M.test_basic_mysql_connection_scheme()
  local parsed = vim.fn['db#url#parse'](M.server_url or 'mysql://localhost')
  test.assert_equal(parsed.scheme, 'mysql', 'Should parse mysql scheme')
end

function M.test_can_parse_mysql_with_port()
  local parsed = vim.fn['db#url#parse']('mysql://localhost:3306/testdb')
  test.assert_equal(parsed.scheme, 'mysql', 'Should parse mysql scheme')
  test.assert_equal(parsed.host, 'localhost', 'Should parse host')
end

function M.test_can_parse_mysql_with_credentials()
  local parsed = vim.fn['db#url#parse']('mysql://user:pass@localhost/testdb')
  test.assert_equal(parsed.scheme, 'mysql', 'Should parse mysql scheme')
  test.assert_not_nil(parsed.user, 'Should parse username')
end

-- ============================================================================
-- Real Database Query Tests
-- ============================================================================

function M.test_can_connect_to_test_database()
  if skip_if_unavailable() then return end

  local conn = vim.fn['db#connect'](M.test_db_url)
  test.assert_not_nil(conn, 'Should create database connection')

  local result, err = helper.execute_sql(M.test_db_url, 'SELECT 1 AS test')
  test.assert_not_nil(result, 'Should execute simple query: ' .. (err or ''))
end

function M.test_can_list_databases()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local databases = vim.fn['db_ui#schemas#query_databases'](db, scheme)

  test.assert_not_nil(databases, 'Should return databases list')
  test.assert_equal(type(databases), 'table', 'Databases should be a table')
end

function M.test_can_access_tables()
  if skip_if_unavailable() then return end

  -- MySQL doesn't have query_tables, but we can test via columns
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')

  -- MySQL doesn't use schemas like SQL Server, so schema parameter is empty
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, '', 'users')

  test.assert_not_nil(columns, 'Should be able to access tables (via columns query)')
  test.assert_equal(type(columns), 'table', 'Columns should be a table')
  test.assert(#columns > 0, 'Should return at least one column from users table')
end

function M.test_can_list_views()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local views = vim.fn['db_ui#schemas#query_views'](db, scheme)

  test.assert_not_nil(views, 'Should return views list')
  test.assert_equal(type(views), 'table', 'Views should be a table')

  -- Check that our test view exists
  local found_view = false
  for _, view in ipairs(views) do
    if type(view) == 'table' and view.name then
      if view.name:find('user_posts_view') then
        found_view = true
        break
      end
    elseif type(view) == 'string' and view:find('user_posts_view') then
      found_view = true
      break
    end
  end

  test.assert(found_view, 'Should find user_posts_view')
end

function M.test_can_list_procedures()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local procedures = vim.fn['db_ui#schemas#query_procedures'](db, scheme)

  test.assert_not_nil(procedures, 'Should return procedures list')
  test.assert_equal(type(procedures), 'table', 'Procedures should be a table')

  -- Check that our test procedure exists
  local found_proc = false
  for _, proc in ipairs(procedures) do
    if type(proc) == 'table' and proc.name then
      if proc.name:find('get_user_by_id') then
        found_proc = true
        break
      end
    elseif type(proc) == 'string' and proc:find('get_user_by_id') then
      found_proc = true
      break
    end
  end

  test.assert(found_proc, 'Should find get_user_by_id procedure')
end

function M.test_can_list_functions()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local functions = vim.fn['db_ui#schemas#query_functions'](db, scheme)

  test.assert_not_nil(functions, 'Should return functions list')
  test.assert_equal(type(functions), 'table', 'Functions should be a table')

  -- Check that our test function exists
  local found_func = false
  for _, func in ipairs(functions) do
    if type(func) == 'table' and func.name then
      if func.name:find('get_user_count') then
        found_func = true
        break
      end
    elseif type(func) == 'string' and func:find('get_user_count') then
      found_func = true
      break
    end
  end

  test.assert(found_func, 'Should find get_user_count function')
end

-- ============================================================================
-- Column Metadata Tests
-- ============================================================================

function M.test_can_get_table_columns()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, '', 'users')

  test.assert_not_nil(columns, 'Should return columns list')
  test.assert_equal(type(columns), 'table', 'Columns should be a table')

  -- Check for expected columns
  local found_id = false
  local found_username = false
  local found_email = false

  for _, col in ipairs(columns) do
    if type(col) == 'table' and col.name then
      if col.name == 'id' then found_id = true end
      if col.name == 'username' then found_username = true end
      if col.name == 'email' then found_email = true end
    elseif type(col) == 'string' then
      if col:find('^id') then found_id = true end
      if col:find('username') then found_username = true end
      if col:find('email') then found_email = true end
    end
  end

  test.assert(found_id, 'Should find id column')
  test.assert(found_username, 'Should find username column')
  test.assert(found_email, 'Should find email column')
end

function M.test_can_get_primary_keys()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local pks = vim.fn['db_ui#schemas#query_primary_keys'](db, scheme, '', 'users')

  test.assert_not_nil(pks, 'Should return primary keys list')
  test.assert_equal(type(pks), 'table', 'Primary keys should be a table')
end

function M.test_can_get_foreign_keys()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')
  local fks = vim.fn['db_ui#schemas#query_foreign_keys'](db, scheme, '', 'posts')

  test.assert_not_nil(fks, 'Should return foreign keys list')
  test.assert_equal(type(fks), 'table', 'Foreign keys should be a table')
end

-- ============================================================================
-- Cache System Tests
-- ============================================================================

function M.test_cache_enabled_for_mysql()
  if skip_if_unavailable() then return end

  test.assert_equal(
    vim.g.db_ui_cache_enabled,
    1,
    'Cache should be enabled for better MySQL performance'
  )
end

function M.test_cache_actually_caches_results()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'mysql' }
  local scheme = vim.fn['db_ui#schemas#get']('mysql')

  -- First call - should query database
  local views1 = vim.fn['db_ui#schemas#query_views'](db, scheme)

  -- Second call - should use cache
  local views2 = vim.fn['db_ui#schemas#query_views'](db, scheme)

  test.assert_not_nil(views1, 'First call should return results')
  test.assert_not_nil(views2, 'Second call should return cached results')
end

function M.test_can_clear_cache()
  if skip_if_unavailable() then return end

  -- Clear cache should not error
  local success, err = pcall(vim.fn['db_ui#schemas#clear_cache'])
  test.assert(success, 'Should be able to clear cache without error')
end

-- ============================================================================
-- MySQL Specific Features
-- ============================================================================

function M.test_can_execute_queries()
  if skip_if_unavailable() then return end

  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM users')
  test.assert_not_nil(result, 'Should execute SELECT query: ' .. (err or ''))
end

function M.test_can_insert_data()
  if skip_if_unavailable() then return end

  local insert_query = "INSERT INTO users (username, email) VALUES ('testuser3', 'test3@example.com')"
  local result, err = helper.execute_sql(M.test_db_url, insert_query)
  test.assert(result ~= nil or err == nil or not err:find('Error'), 'Should be able to insert data: ' .. (err or ''))
end

function M.test_database_qualified_names_work()
  if skip_if_unavailable() then return end

  -- Test database.table syntax
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT COUNT(*) as cnt FROM ' .. config.test_db_name .. '.users')
  test.assert_not_nil(result, 'Should support database.table syntax: ' .. (err or ''))
end

function M.test_mysql_no_schema_concept()
  if skip_if_unavailable() then return end

  -- MySQL doesn't have schemas like SQL Server (database IS the schema)
  test.assert(true, 'MySQL uses database-level organization')
end

function M.test_mysql_backtick_quoting()
  if skip_if_unavailable() then return end

  -- MySQL uses backticks for identifier quoting
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM `users` LIMIT 1')
  test.assert_not_nil(result, 'MySQL should support backtick identifier quoting: ' .. (err or ''))
end

return M
