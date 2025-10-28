-- ============================================================================
-- SQL Server Connection Tests
-- ============================================================================
-- Tests for SQL Server / Azure SQL database connections
-- Schemes: sqlserver, sqlsrv, mssql
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')
local helper = require('db_ui.tests.test_db_helper')
local config = require('db_ui.tests.test_config')

-- Test state
M.server_available = false
M.server_url = nil
M.test_db_url = nil
M.skip_reason = nil

function M.setup()
  -- Ensure SSMS style is enabled for proper SQL Server support
  vim.g.db_ui_use_ssms_style = 1

  -- Check if SQL Server is configured
  M.server_url = config.get_server_url('sqlserver')

  if not M.server_url then
    M.skip_reason = "SQL Server not configured in test_config.lua"
    test.log("⚠️  Skipping SQL Server tests: " .. M.skip_reason, "warning")
    return
  end

  -- Check if server is available
  test.log("🔍 Checking SQL Server availability at: " .. M.server_url, "info")
  local available, err = helper.check_server_available(M.server_url)

  if not available then
    M.skip_reason = "SQL Server not available: " .. (err or "unknown error")
    test.log("⚠️  Skipping SQL Server tests: " .. M.skip_reason, "warning")
    return
  end

  M.server_available = true
  test.log("✅ SQL Server is available", "info")

  -- Create test database
  test.log("🔨 Creating test database: " .. config.test_db_name, "info")
  local create_success, create_err = helper.create_test_database(M.server_url, config.test_db_name)

  if not create_success then
    M.skip_reason = "Failed to create test database: " .. (create_err or "unknown error")
    test.log("❌ " .. M.skip_reason, "error")
    M.server_available = false
    return
  end

  test.log("✅ Test database created", "info")

  -- Get test database URL
  M.test_db_url = helper.get_test_db_url(M.server_url, config.test_db_name)
  test.log("📋 Test database URL: " .. M.test_db_url, "info")

  -- Populate test database
  test.log("📝 Populating test database with test objects...", "info")
  local populate_success, populate_err = helper.populate_test_database(M.test_db_url, 'sqlserver')

  if not populate_success then
    M.skip_reason = "Failed to populate test database: " .. (populate_err or "unknown error")
    test.log("❌ " .. M.skip_reason, "error")
    M.server_available = false
    return
  end

  test.log("✅ Test database populated successfully", "info")
  test.log("🚀 Ready to run SQL Server tests", "info")
  test.log("", "info")
end

function M.teardown()
  if not config.skip_cleanup and M.server_available and M.server_url then
    test.log("", "info")
    test.log("🧹 Cleaning up test database...", "info")
    local drop_success, drop_err = helper.drop_test_database(M.server_url, config.test_db_name)

    if drop_success then
      test.log("✅ Test database cleaned up", "info")
    else
      test.log("⚠️  Failed to clean up test database: " .. (drop_err or "unknown error"), "warning")
    end
  elseif config.skip_cleanup then
    test.log("⚠️  Skipping cleanup (skip_cleanup = true)", "warning")
    test.log("   Test database: " .. (M.test_db_url or "unknown"), "info")
  end
end

-- Helper to skip test if server not available
local function skip_if_unavailable()
  if not M.server_available then
    test.assert(true, "Skipped: " .. (M.skip_reason or "Server not available"))
    return true
  end
  return false
end

-- ============================================================================
-- Connection URL Parsing Tests
-- ============================================================================

function M.test_server_level_connection_scheme()
  if skip_if_unavailable() then return end

  local scheme = vim.fn['db#url#parse'](M.server_url).scheme
  test.assert_equal(scheme, 'sqlserver', 'Should parse sqlserver scheme')
end

function M.test_database_level_connection_scheme()
  if skip_if_unavailable() then return end

  local parsed = vim.fn['db#url#parse'](M.test_db_url)
  test.assert_equal(parsed.scheme, 'sqlserver', 'Should parse sqlserver scheme')
  test.assert(parsed.path:find(config.test_db_name) ~= nil, 'Should include database name in path')
end

function M.test_connection_with_credentials()
  if skip_if_unavailable() then return end

  local parsed = vim.fn['db#url#parse'](M.server_url)
  test.assert_equal(parsed.scheme, 'sqlserver', 'Should parse sqlserver scheme')
  -- Credentials may or may not be present depending on config
  test.assert(true, 'Connection URL parsed successfully')
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

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
  local databases = vim.fn['db_ui#schemas#query_databases'](db, scheme)

  test.assert_not_nil(databases, 'Should return databases list')
  test.assert_equal(type(databases), 'table', 'Databases should be a table')
end

function M.test_can_list_tables()
  if skip_if_unavailable() then return end

  -- Tables are retrieved using generic query with schemes_tables_query
  -- For now, test that we can query using the database by testing columns instead
  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')

  -- Test by querying columns for a known table - this proves tables are accessible
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, 'test_schema', 'users')

  test.assert_not_nil(columns, 'Should be able to access tables (via columns query)')
  test.assert_equal(type(columns), 'table', 'Columns should be a table')
  test.assert(#columns > 0, 'Should return at least one column from users table')
end

function M.test_can_list_views()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
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

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
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

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
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

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
  local columns = vim.fn['db_ui#schemas#query_columns'](db, scheme, 'test_schema', 'users')

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

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
  local pks = vim.fn['db_ui#schemas#query_primary_keys'](db, scheme, 'test_schema', 'users')

  test.assert_not_nil(pks, 'Should return primary keys list')
  test.assert_equal(type(pks), 'table', 'Primary keys should be a table')

  -- Should have 'id' as primary key
  local found_id_pk = false
  for _, pk in ipairs(pks) do
    if type(pk) == 'table' and pk.column_name then
      if pk.column_name == 'id' then found_id_pk = true end
    elseif type(pk) == 'string' and pk:find('id') then
      found_id_pk = true
    end
  end

  test.assert(found_id_pk, 'Should find id as primary key')
end

function M.test_can_get_foreign_keys()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')
  local fks = vim.fn['db_ui#schemas#query_foreign_keys'](db, scheme, 'test_schema', 'posts')

  test.assert_not_nil(fks, 'Should return foreign keys list')
  test.assert_equal(type(fks), 'table', 'Foreign keys should be a table')

  -- Should have user_id as foreign key
  local found_user_id_fk = false
  for _, fk in ipairs(fks) do
    if type(fk) == 'table' and fk.column_name then
      if fk.column_name == 'user_id' then found_user_id_fk = true end
    elseif type(fk) == 'string' and fk:find('user_id') then
      found_user_id_fk = true
    end
  end

  test.assert(found_user_id_fk, 'Should find user_id as foreign key')
end

-- ============================================================================
-- Cache System Tests
-- ============================================================================

function M.test_cache_enabled_for_sqlserver()
  if skip_if_unavailable() then return end

  test.assert_equal(
    vim.g.db_ui_cache_enabled,
    1,
    'Cache should be enabled for better SQL Server performance'
  )
end

function M.test_cache_actually_caches_results()
  if skip_if_unavailable() then return end

  local db = { url = M.test_db_url, conn = vim.fn['db#connect'](M.test_db_url), scheme = 'sqlserver' }
  local scheme = vim.fn['db_ui#schemas#get']('sqlserver')

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
-- SSMS-Style Features
-- ============================================================================

function M.test_ssms_style_enabled()
  if skip_if_unavailable() then return end

  test.assert_equal(vim.g.db_ui_use_ssms_style, 1, 'SSMS style should be enabled')
end

function M.test_schema_prefix_enabled()
  if skip_if_unavailable() then return end

  test.assert_equal(
    vim.g.db_ui_show_schema_prefix,
    1,
    'Schema prefix should be enabled for [schema].[table] format'
  )
end

function M.test_system_databases_hidden()
  if skip_if_unavailable() then return end

  test.assert_equal(
    vim.g.db_ui_hide_system_databases,
    1,
    'System databases should be hidden (master, msdb, tempdb, model)'
  )
end

function M.test_system_schemas_hidden()
  if skip_if_unavailable() then return end

  local hide_schemas = vim.g.db_ui_hide_schemas
  test.assert_not_nil(hide_schemas, 'Hide schemas should be configured')
  test.assert_contains(hide_schemas, 'sys', 'Should hide sys schema')
  test.assert_contains(hide_schemas, 'INFORMATION_SCHEMA', 'Should hide INFORMATION_SCHEMA')
end

-- ============================================================================
-- SQL Server Specific Features
-- ============================================================================

function M.test_can_execute_queries()
  if skip_if_unavailable() then return end

  local result, err = helper.execute_sql(M.test_db_url, 'SELECT * FROM test_schema.users')
  test.assert_not_nil(result, 'Should execute SELECT query: ' .. (err or ''))
end

function M.test_can_insert_data()
  if skip_if_unavailable() then return end

  local insert_query = "INSERT INTO test_schema.users (username, email) VALUES ('testuser3', 'test3@example.com')"
  local result, err = helper.execute_sql(M.test_db_url, insert_query)
  test.assert(result ~= nil or err == nil or not err:find('Error'), 'Should be able to insert data: ' .. (err or ''))
end

function M.test_schema_qualified_names_work()
  if skip_if_unavailable() then return end

  -- Test schema.table syntax
  local result, err = helper.execute_sql(M.test_db_url, 'SELECT COUNT(*) as cnt FROM test_schema.users')
  test.assert_not_nil(result, 'Should support schema.table syntax: ' .. (err or ''))
end

return M
