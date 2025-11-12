" Comprehensive IntelliSense Manual Test Script
" This script provides manual testing scenarios for the IntelliSense implementation
"
" Prerequisites:
" 1. SQL Server running on localhost (SQLEXPRESS)
" 2. vim_dadbod_test database with synonyms created
" 3. TEST database with Records table
" 4. DBUI connection configured: sqlserver://localhost
"
" Usage:
" 1. Open this file in Neovim: :e test_intellisense_manual.vim
" 2. Source it: :source %
" 3. Run tests: :call RunIntelliSenseTests()
" 4. For interactive testing, follow the manual test scenarios below

" =============================================================================
" MANUAL TEST SCENARIOS
" =============================================================================
"
" After sourcing this file, you can manually test the following scenarios:
"
" SCENARIO 1: Synonym Resolution in DBUI Tree
" --------------------------------------------
" 1. Open DBUI: :DBUI
" 2. Expand your server connection (sqlserver://localhost)
" 3. Expand vim_dadbod_test database
" 4. Look for SYNONYMS section (should be visible alongside TABLES, VIEWS, etc.)
" 5. Expand SYNONYMS
" Expected: Should see syn_Employees, syn_ActiveEmployees, syn_TestRecords, syn_ExternalTable
"
" SCENARIO 2: Synonym IntelliSense - Direct Synonym
" --------------------------------------------------
" 1. Create a new query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM syn_Employees.
"                                       ^ cursor here after the dot
" Expected: IntelliSense should show columns from dbo.Employees table
"           (EmployeeID, FirstName, LastName, DepartmentID, Email, HireDate, Salary, IsActive)
"
" SCENARIO 3: Synonym IntelliSense - Cross-Database Synonym
" ----------------------------------------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM syn_TestRecords.
"                                        ^ cursor here
" Expected: IntelliSense should show columns from TEST.dbo.Records table
"           (ID, Name, Value, CreatedDate)
"
" SCENARIO 4: External Database - All Object Types
" -------------------------------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM TEST.dbo.
"                                 ^ cursor here
" Expected: IntelliSense should show all objects in TEST.dbo (tables, views, procedures, functions)
"           Should see at least the Records table
"
" SCENARIO 5: Schema Objects - All Types
" ---------------------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM dbo.
"                            ^ cursor here
" Expected: IntelliSense should show all object types (tables, views, procedures, functions, synonyms)
"           Should see Employees, vw_ActiveEmployees, syn_Employees, etc.
"
" SCENARIO 6: Database List
" --------------------------
" 1. In a query buffer connected to server (sqlserver://localhost)
" 2. Type: SELECT * FROM vim
"                           ^ cursor here (partial database name)
" Expected: IntelliSense should show vim_dadbod_test database
"
" SCENARIO 7: Schema List After Database
" ---------------------------------------
" 1. In a query buffer
" 2. Type: SELECT * FROM vim_dadbod_test.
"                                        ^ cursor here
" Expected: IntelliSense should show schemas (dbo, hr)
"
" SCENARIO 8: Cross-Database Object Access
" -----------------------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM TEST.dbo.Records.
"                                         ^ cursor here
" Expected: IntelliSense should show columns from TEST.dbo.Records
"           (ID, Name, Value, CreatedDate)
"
" SCENARIO 9: HR Schema Objects
" ------------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM hr.
"                           ^ cursor here
" Expected: IntelliSense should show hr schema objects
"           Should see Benefits table, vw_BenefitsWithDept view, usp_GetBenefitsByType procedure, fn_GetBenefitCount function
"
" SCENARIO 10: Synonym to View
" -----------------------------
" 1. In a query buffer connected to vim_dadbod_test
" 2. Type: SELECT * FROM syn_ActiveEmployees.
"                                            ^ cursor here
" Expected: IntelliSense should show columns from vw_ActiveEmployees view
"           (EmployeeID, FirstName, LastName, DepartmentID, Email, HireDate, Salary)

" =============================================================================
" AUTOMATED VERIFICATION TESTS
" =============================================================================

let s:test_results = {
      \ 'passed': 0,
      \ 'failed': 0,
      \ 'tests': []
      \ }

function! s:print_result(test_name, passed, expected, actual) abort
  let status = a:passed ? '✓ PASS' : '✗ FAIL'
  let result = {
        \ 'name': a:test_name,
        \ 'passed': a:passed,
        \ 'expected': a:expected,
        \ 'actual': a:actual
        \ }

  call add(s:test_results.tests, result)

  if a:passed
    let s:test_results.passed += 1
    echohl MoreMsg
    echo status . ': ' . a:test_name
    echohl None
  else
    let s:test_results.failed += 1
    echohl ErrorMsg
    echo status . ': ' . a:test_name
    echohl None
    echohl WarningMsg
    echo '  Expected: ' . string(a:expected)
    echo '  Actual: ' . string(a:actual)
    echohl None
  endif
endfunction

" Test 1: Verify connection exists
function! s:test_01_verify_connection() abort
  try
    " Initialize DBUI first
    call db_ui#toggle()
    sleep 100m
    call db_ui#toggle()

    " Now check connection
    let conn_info = db_ui#get_conn_info('sqlserver://localhost')
    let passed = !empty(conn_info)
    call s:print_result('Verify DBUI connection exists', passed, 'Connection object', passed ? 'Found' : 'Not found')
  catch
    call s:print_result('Verify DBUI connection exists', 0, 'Connection object', 'Error: ' . v:exception)
  endtry
endfunction

" Test 2: Verify configuration - SSMS style enabled
function! s:test_02_ssms_style_config() abort
  let ssms_enabled = get(g:, 'db_ui_use_ssms_style', 0)
  let passed = ssms_enabled == 1
  call s:print_result('SSMS style enabled in config', passed, 1, ssms_enabled)
endfunction

" Test 3: Verify configuration - object types include synonyms
function! s:test_03_synonyms_in_config() abort
  let object_types = get(g:, 'db_ui_ssms_object_types', [])
  let has_synonyms = index(object_types, 'synonyms') != -1
  call s:print_result('Synonyms in g:db_ui_ssms_object_types', has_synonyms, 'synonyms in list', has_synonyms ? 'Found' : 'Not found')
endfunction

" Test 4: Verify configuration - lazy loading enabled
function! s:test_04_lazy_loading_config() abort
  let lazy_load = get(g:, 'db_ui_intellisense_lazy_load', 0)
  let passed = lazy_load == 1
  call s:print_result('Lazy loading enabled', passed, 1, lazy_load)
endfunction

" Test 5: Verify configuration - unified cache enabled
function! s:test_05_unified_cache_config() abort
  let unified_cache = get(g:, 'db_ui_unified_cache', 1)
  let passed = unified_cache == 1
  call s:print_result('Unified cache enabled', passed, 1, unified_cache)
endfunction

" Test 6: Verify completion module exists
function! s:test_06_completion_module_exists() abort
  let has_completion = exists('*db_ui#completion#get_cursor_context')
  call s:print_result('Completion module loaded', has_completion, 'Function exists', has_completion ? 'Found' : 'Not found')
endfunction

" Test 7: Verify schemas module has synonym query
function! s:test_07_schemas_synonym_query() abort
  let has_synonym_query = exists('*db_ui#schemas#query_synonyms')
  call s:print_result('Schemas module has synonym query function', has_synonym_query, 'Function exists', has_synonym_query ? 'Found' : 'Not found')
endfunction

" Test 8: DBUI can open
function! s:test_08_dbui_can_open() abort
  try
    " Try to open DBUI - db_ui#open() requires a 'mods' argument
    call db_ui#toggle()
    sleep 500m
    let passed = &filetype ==# 'dbui'
    call s:print_result('DBUI can open', passed, 'dbui filetype', &filetype)
    " Close DBUI
    if passed
      call db_ui#close()
    endif
  catch
    call s:print_result('DBUI can open', 0, 'Success', 'Error: ' . v:exception)
  endtry
endfunction

" Test 9: Cache can be cleared
function! s:test_09_cache_clear() abort
  try
    call db_ui#schemas#clear_cache()
    call s:print_result('Cache can be cleared', 1, 'Success', 'Success')
  catch
    call s:print_result('Cache can be cleared', 0, 'Success', 'Error: ' . v:exception)
  endtry
endfunction

" Test 10: Verify blink.cmp source exists (if blink is installed)
function! s:test_10_blink_source() abort
  if !has('nvim')
    call s:print_result('Blink.cmp source exists', 1, 'N/A (Vim)', 'Skipped')
    return
  endif

  try
    let blink_loaded = luaeval("pcall(require, 'blink.cmp.sources.dadbod')")
    call s:print_result('Blink.cmp source loaded', blink_loaded, 'Module loadable', blink_loaded ? 'Yes' : 'No')
  catch
    call s:print_result('Blink.cmp source loaded', 0, 'Module loadable', 'Error: ' . v:exception)
  endtry
endfunction

" Main test runner
function! RunIntelliSenseTests() abort
  echo "\n"
  echohl Title
  echo '=== Comprehensive IntelliSense Test Suite ==='
  echohl None
  echo "\n"

  " Reset results
  let s:test_results = {'passed': 0, 'failed': 0, 'tests': []}

  " Run automated tests
  call s:test_01_verify_connection()
  call s:test_02_ssms_style_config()
  call s:test_03_synonyms_in_config()
  call s:test_04_lazy_loading_config()
  call s:test_05_unified_cache_config()
  call s:test_06_completion_module_exists()
  call s:test_07_schemas_synonym_query()
  call s:test_08_dbui_can_open()
  call s:test_09_cache_clear()
  call s:test_10_blink_source()

  " Print summary
  echo "\n"
  echohl Title
  echo '=== Test Summary ==='
  echohl None
  let total = s:test_results.passed + s:test_results.failed
  echo 'Total tests: ' . total
  echohl MoreMsg
  echo 'Passed: ' . s:test_results.passed
  echohl None
  if s:test_results.failed > 0
    echohl ErrorMsg
    echo 'Failed: ' . s:test_results.failed
    echohl None
  else
    echo 'Failed: 0'
  endif

  if total > 0
    let success_rate = (s:test_results.passed * 100.0) / total
    echo printf('Success rate: %.1f%%', success_rate)
  endif

  echo "\n"
  if s:test_results.failed > 0
    echohl ErrorMsg
    echo '❌ Some tests failed. Review the output above for details.'
    echohl None
  else
    echohl MoreMsg
    echo '✅ All automated tests passed!'
    echohl None
  endif

  echo "\n"
  echohl WarningMsg
  echo '📝 For complete testing, please run the manual test scenarios at the top of this file.'
  echohl None
  echo "\n"
endfunction

" Utility: Open DBUI and expand to synonyms
function! OpenDBUIAndShowSynonyms() abort
  call db_ui#toggle()
  echo 'DBUI opened. Navigate to your server → vim_dadbod_test → SYNONYMS to view synonyms.'
endfunction

" Utility: Create a test query buffer
function! CreateTestQueryBuffer() abort
  " Create a new buffer for testing queries
  enew
  setlocal buftype=nofile
  setlocal filetype=sql

  " Set up buffer variables for database connection
  let b:dbui_db_key_name = 'sqlserver://localhost'
  let b:db = db#connect('sqlserver://localhost/vim_dadbod_test')

  echo 'Test query buffer created. Connected to vim_dadbod_test.'
  echo 'Try typing: SELECT * FROM syn_Employees.'
  echo 'Or: SELECT * FROM TEST.dbo.'
endfunction

" Utility: Show help
function! ShowTestHelp() abort
  echo "\n"
  echohl Title
  echo '=== IntelliSense Test Commands ==='
  echohl None
  echo "\n"
  echo 'Automated Tests:'
  echo '  :call RunIntelliSenseTests()         - Run all automated verification tests'
  echo "\n"
  echo 'Manual Testing Utilities:'
  echo '  :call OpenDBUIAndShowSynonyms()      - Open DBUI to view synonyms in tree'
  echo '  :call CreateTestQueryBuffer()        - Create a SQL buffer for testing completions'
  echo "\n"
  echo 'Manual Test Scenarios:'
  echo '  See the top of this file for detailed manual test scenarios'
  echo '  :e test_intellisense_manual.vim'
  echo "\n"
endfunction

" Auto-run tests when sourced
echohl MoreMsg
echo 'IntelliSense test script loaded!'
echohl None
echo 'Run :call RunIntelliSenseTests() to start automated tests'
echo 'Run :call ShowTestHelp() for all available commands'
echo "\n"
