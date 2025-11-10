-- Comprehensive IntelliSense Test Suite
-- Tests synonym resolution, all object types loading, hierarchical resolution, and cross-database references
--
-- Prerequisites:
-- 1. SQL Server running on localhost (SQLEXPRESS)
-- 2. vim_dadbod_test database with synonyms created (see setup SQL)
-- 3. TEST database with Records table
-- 4. DBUI connection configured: sqlserver://localhost
--
-- Run with: :luafile %

local M = {}

-- Test configuration
local test_config = {
  db_key_name = 'sqlserver://localhost',  -- Your server connection
  test_db = 'vim_dadbod_test',
  external_db = 'TEST',
  timeout = 5000,  -- 5 second timeout for async operations
}

-- Test results tracking
local test_results = {
  passed = 0,
  failed = 0,
  tests = {}
}

-- Helper function to print test results
local function print_result(test_name, passed, expected, actual)
  local status = passed and '✓ PASS' or '✗ FAIL'
  local result = {
    name = test_name,
    passed = passed,
    expected = expected,
    actual = actual
  }

  table.insert(test_results.tests, result)

  if passed then
    test_results.passed = test_results.passed + 1
    print(string.format('%s: %s', status, test_name))
  else
    test_results.failed = test_results.failed + 1
    print(string.format('%s: %s', status, test_name))
    print(string.format('  Expected: %s', vim.inspect(expected)))
    print(string.format('  Actual: %s', vim.inspect(actual)))
  end
end

-- Helper function to wait for async operations
local function wait_for_completion(check_fn, timeout)
  local start_time = vim.loop.hrtime()
  local timeout_ns = timeout * 1000000  -- Convert ms to nanoseconds

  while not check_fn() do
    local elapsed = vim.loop.hrtime() - start_time
    if elapsed > timeout_ns then
      return false  -- Timeout
    end
    vim.wait(100)  -- Wait 100ms between checks
  end

  return true
end

-- Test 1: Verify DBUI connection exists
function M.test_01_verify_connection()
  local db = vim.fn['db_ui#get_conn_info'](test_config.db_key_name)
  local passed = db ~= nil and db ~= ''
  print_result('Verify DBUI connection exists', passed, 'Connection object', db ~= nil and 'Found' or 'Not found')
end

-- Test 2: Verify synonym loading in DBUI tree
function M.test_02_synonym_tree_structure()
  -- Open DBUI to ensure structures are loaded
  vim.cmd('DBUI')
  vim.wait(500)  -- Wait for UI to load

  -- Check if synonyms are in the structure
  local db_entry = vim.fn['s:get_dbui_database'](test_config.db_key_name)

  -- Check for object_types.synonyms structure
  local has_synonyms_structure = false
  if type(db_entry) == 'table' then
    if db_entry.object_types and db_entry.object_types.synonyms then
      has_synonyms_structure = true
    end
  end

  print_result('DBUI tree has synonyms structure', has_synonyms_structure, 'object_types.synonyms exists', has_synonyms_structure and 'Found' or 'Not found')
end

-- Test 3: Synonym resolution - syn_Employees
function M.test_03_resolve_synonym_employees()
  local resolved = vim.fn['s:resolve_synonym'](test_config.db_key_name, 'syn_Employees')

  local expected = {
    database = '',
    schema = 'dbo',
    table = 'Employees'
  }

  local passed = resolved.schema == 'dbo' and resolved.table == 'Employees'
  print_result('Resolve synonym syn_Employees → dbo.Employees', passed, expected, resolved)
end

-- Test 4: Synonym resolution - syn_TestRecords (cross-database)
function M.test_04_resolve_cross_database_synonym()
  local resolved = vim.fn['s:resolve_synonym'](test_config.db_key_name, 'syn_TestRecords')

  local expected = {
    database = 'TEST',
    schema = 'dbo',
    table = 'Records'
  }

  local passed = resolved.database == 'TEST' and resolved.schema == 'dbo' and resolved.table == 'Records'
  print_result('Resolve cross-database synonym syn_TestRecords → TEST.dbo.Records', passed, expected, resolved)
end

-- Test 5: Synonym detection
function M.test_05_is_synonym_detection()
  local is_syn_1 = vim.fn['s:is_synonym'](test_config.db_key_name, 'syn_Employees')
  local is_syn_2 = vim.fn['s:is_synonym'](test_config.db_key_name, 'syn_ActiveEmployees')
  local is_not_syn = vim.fn['s:is_synonym'](test_config.db_key_name, 'Employees')

  local passed = is_syn_1 == 1 and is_syn_2 == 1 and is_not_syn == 0
  print_result('Synonym detection works correctly', passed, 'syn_* detected, Employees not',
    string.format('syn_Employees=%s, syn_ActiveEmployees=%s, Employees=%s', is_syn_1, is_syn_2, is_not_syn))
end

-- Test 6: Get synonyms from DBUI
function M.test_06_get_synonyms_from_dbui()
  local synonyms = vim.fn['s:get_synonyms_from_dbui'](test_config.db_key_name)

  local synonym_count = 0
  local has_syn_employees = false
  local has_syn_test_records = false

  if type(synonyms) == 'table' then
    synonym_count = #synonyms
    for _, syn in ipairs(synonyms) do
      if type(syn) == 'table' then
        if syn.name == 'syn_Employees' then
          has_syn_employees = true
        elseif syn.name == 'syn_TestRecords' then
          has_syn_test_records = true
        end
      end
    end
  end

  local passed = synonym_count >= 4 and has_syn_employees and has_syn_test_records
  print_result('Get synonyms from DBUI (4 expected)', passed, '4 synonyms including syn_Employees and syn_TestRecords',
    string.format('%d synonyms, has_syn_Employees=%s, has_syn_TestRecords=%s', synonym_count, has_syn_employees, has_syn_test_records))
end

-- Test 7: Hierarchical context - synonym with dot
function M.test_07_hierarchical_synonym_context()
  -- Simulate typing "syn_Employees." in a query buffer
  local parts = {'syn_Employees'}
  local cursor_char = '.'

  -- Call hierarchical resolution
  local context = vim.fn['db_ui#completion#get_hierarchical_context'](test_config.db_key_name, parts, cursor_char)

  -- Should resolve to column context for Employees table
  local passed = context.type == 'column' and context.table == 'Employees'
  print_result('Hierarchical context: syn_Employees. → columns', passed,
    {type = 'column', table = 'Employees'},
    {type = context.type, table = context.table})
end

-- Test 8: Load all object types for external database
function M.test_08_load_all_object_types_external_db()
  -- Ensure external database objects are loaded
  vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'tables')
  vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'views')
  vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'procedures')
  vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'functions')
  vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'synonyms')

  vim.wait(1000)  -- Wait for async loading

  -- Check if TEST database objects are loaded
  local tables = vim.fn['s:get_tables_from_dbui'](test_config.db_key_name, 'TEST')

  local has_records = false
  if type(tables) == 'table' then
    for _, tbl in ipairs(tables) do
      local tbl_name = type(tbl) == 'table' and tbl.name or tbl
      if tbl_name == 'Records' then
        has_records = true
        break
      end
    end
  end

  local passed = has_records
  print_result('Load all object types for external database TEST', passed, 'Records table found', has_records and 'Found' or 'Not found')
end

-- Test 9: Hierarchical context - external database with schema
function M.test_09_hierarchical_external_db_schema()
  -- Simulate typing "TEST.dbo." in a query buffer
  local parts = {'TEST', 'dbo'}
  local cursor_char = '.'

  local context = vim.fn['db_ui#completion#get_hierarchical_context'](test_config.db_key_name, parts, cursor_char)

  -- Should show objects in TEST.dbo schema
  local passed = context.type == 'object' and context.database == 'TEST' and context.schema == 'dbo'
  print_result('Hierarchical context: TEST.dbo. → objects', passed,
    {type = 'object', database = 'TEST', schema = 'dbo'},
    {type = context.type, database = context.database, schema = context.schema})
end

-- Test 10: Hierarchical context - database only
function M.test_10_hierarchical_database_only()
  -- Simulate typing "vim_dadbod_test." in a query buffer
  local parts = {'vim_dadbod_test'}
  local cursor_char = '.'

  local context = vim.fn['db_ui#completion#get_hierarchical_context'](test_config.db_key_name, parts, cursor_char)

  -- Should show schemas in vim_dadbod_test
  local passed = context.type == 'schema' and context.database == 'vim_dadbod_test'
  print_result('Hierarchical context: vim_dadbod_test. → schemas', passed,
    {type = 'schema', database = 'vim_dadbod_test'},
    {type = context.type, database = context.database})
end

-- Test 11: Verify synonym in object types list
function M.test_11_synonyms_in_object_types_config()
  local object_types = vim.g.db_ui_ssms_object_types or {}

  local has_synonyms = false
  for _, obj_type in ipairs(object_types) do
    if obj_type == 'synonyms' then
      has_synonyms = true
      break
    end
  end

  local passed = has_synonyms
  print_result('Synonyms in g:db_ui_ssms_object_types config', passed, 'synonyms in list', has_synonyms and 'Found' or 'Not found')
end

-- Test 12: Lazy loading enabled
function M.test_12_lazy_loading_config()
  local lazy_load = vim.g.db_ui_intellisense_lazy_load or 0
  local passed = lazy_load == 1
  print_result('Lazy loading enabled in config', passed, 1, lazy_load)
end

-- Test 13: Get columns for synonym target
function M.test_13_columns_for_synonym_target()
  -- Resolve synonym first
  local resolved = vim.fn['s:resolve_synonym'](test_config.db_key_name, 'syn_Employees')

  if resolved.table then
    -- Get columns for the target table
    local columns = vim.fn['s:get_columns_from_dbui'](test_config.db_key_name, '', resolved.schema, resolved.table)

    local column_count = type(columns) == 'table' and #columns or 0
    local passed = column_count > 0
    print_result('Get columns for synonym target (syn_Employees → Employees)', passed, '> 0 columns',
      string.format('%d columns', column_count))
  else
    print_result('Get columns for synonym target (syn_Employees → Employees)', false, 'Resolved synonym', 'Failed to resolve')
  end
end

-- Test 14: Cross-database synonym with external DB loading
function M.test_14_cross_database_synonym_with_loading()
  -- Resolve cross-database synonym
  local resolved = vim.fn['s:resolve_synonym'](test_config.db_key_name, 'syn_TestRecords')

  if resolved.database == 'TEST' and resolved.table == 'Records' then
    -- Ensure external DB is loaded
    vim.fn['db_ui#completion#ensure_external_db_objects'](test_config.db_key_name, 'TEST', 'tables')
    vim.wait(1000)

    -- Try to get columns
    local columns = vim.fn['s:get_columns_from_dbui'](test_config.db_key_name, 'TEST', resolved.schema, resolved.table)

    local column_count = type(columns) == 'table' and #columns or 0
    local passed = column_count > 0
    print_result('Cross-database synonym column loading (syn_TestRecords → TEST.dbo.Records)', passed, '> 0 columns',
      string.format('%d columns', column_count))
  else
    print_result('Cross-database synonym column loading (syn_TestRecords → TEST.dbo.Records)', false,
      'Resolved to TEST.dbo.Records', vim.inspect(resolved))
  end
end

-- Test 15: All object types loaded for current database schema
function M.test_15_all_object_types_current_db()
  -- Get all object types for vim_dadbod_test.dbo
  local tables = vim.fn['s:get_tables_from_dbui'](test_config.db_key_name, '')
  local views = vim.fn['s:get_views_from_dbui'](test_config.db_key_name, '')
  local procedures = vim.fn['s:get_procedures_from_dbui'](test_config.db_key_name, '')
  local functions = vim.fn['s:get_functions_from_dbui'](test_config.db_key_name, '')
  local synonyms = vim.fn['s:get_synonyms_from_dbui'](test_config.db_key_name, '')

  local tables_count = type(tables) == 'table' and #tables or 0
  local views_count = type(views) == 'table' and #views or 0
  local procedures_count = type(procedures) == 'table' and #procedures or 0
  local functions_count = type(functions) == 'table' and #functions or 0
  local synonyms_count = type(synonyms) == 'table' and #synonyms or 0

  -- Expected: 6 tables, 4 views, 6 procedures, 5 functions, 4 synonyms (based on your setup)
  local passed = tables_count >= 5 and views_count >= 3 and procedures_count >= 5 and functions_count >= 4 and synonyms_count >= 4

  print_result('All object types loaded for current database', passed,
    '≥5 tables, ≥3 views, ≥5 procedures, ≥4 functions, ≥4 synonyms',
    string.format('%d tables, %d views, %d procedures, %d functions, %d synonyms',
      tables_count, views_count, procedures_count, functions_count, synonyms_count))
end

-- Run all tests
function M.run_all_tests()
  print('\n=== Comprehensive IntelliSense Test Suite ===\n')
  print('Testing against: ' .. test_config.db_key_name)
  print('Test database: ' .. test_config.test_db)
  print('External database: ' .. test_config.external_db)
  print('')

  -- Run tests in order
  M.test_01_verify_connection()
  M.test_02_synonym_tree_structure()
  M.test_03_resolve_synonym_employees()
  M.test_04_resolve_cross_database_synonym()
  M.test_05_is_synonym_detection()
  M.test_06_get_synonyms_from_dbui()
  M.test_07_hierarchical_synonym_context()
  M.test_08_load_all_object_types_external_db()
  M.test_09_hierarchical_external_db_schema()
  M.test_10_hierarchical_database_only()
  M.test_11_synonyms_in_object_types_config()
  M.test_12_lazy_loading_config()
  M.test_13_columns_for_synonym_target()
  M.test_14_cross_database_synonym_with_loading()
  M.test_15_all_object_types_current_db()

  -- Print summary
  print('\n=== Test Summary ===')
  print(string.format('Total tests: %d', test_results.passed + test_results.failed))
  print(string.format('Passed: %d', test_results.passed))
  print(string.format('Failed: %d', test_results.failed))
  print(string.format('Success rate: %.1f%%', (test_results.passed / (test_results.passed + test_results.failed)) * 100))

  if test_results.failed > 0 then
    print('\n❌ Some tests failed. Review the output above for details.')
  else
    print('\n✅ All tests passed!')
  end

  return test_results
end

-- Auto-run when sourced
M.run_all_tests()

return M
