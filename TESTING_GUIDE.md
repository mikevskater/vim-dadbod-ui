# IntelliSense Testing Guide

This guide provides comprehensive testing procedures for the SSMS-style IntelliSense implementation in vim-dadbod-ui.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Test Setup](#test-setup)
3. [Automated Tests](#automated-tests)
4. [Manual Test Scenarios](#manual-test-scenarios)
5. [Expected Results](#expected-results)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Setup

1. **SQL Server**: Running on localhost (SQLEXPRESS instance)
2. **Databases**:
   - `vim_dadbod_test` - Main test database
   - `TEST` - Secondary database for cross-database testing
3. **Database Objects**: Run the setup SQL script (see `sql_setup_script.sql`) to create:
   - Tables: Employees, Departments, Projects, etc.
   - Views: vw_ActiveEmployees, vw_DepartmentSummary, etc.
   - Procedures: usp_GetEmployeesByDepartment, etc.
   - Functions: fn_GetFullName, etc.
   - Synonyms: syn_Employees, syn_ActiveEmployees, syn_TestRecords, syn_ExternalTable
   - HR schema with additional objects

4. **Neovim Configuration**:
   - vim-dadbod plugin installed
   - vim-dadbod-ui plugin installed
   - blink.cmp plugin installed (for completion)
   - DBUI connection configured: `sqlserver://localhost`

### Configuration Verification

Ensure your Neovim config has:

```lua
-- SSMS-style features
vim.g.db_ui_use_ssms_style = 1
vim.g.db_ui_ssms_object_types = {'tables', 'views', 'procedures', 'functions', 'synonyms'}

-- IntelliSense features
vim.g.db_ui_unified_cache = 1
vim.g.db_ui_intellisense_lazy_load = 1
vim.g.db_ui_intellisense_resolve_synonyms = 1

-- Performance
vim.g.db_ui_cache_enabled = 1
vim.g.db_ui_cache_ttl = 300
```

## Test Setup

### SQL Setup Script

If you haven't already, run the SQL setup script to create all required test objects:

```bash
# The script creates:
# - 4 synonyms (various scenarios)
# - hr schema with table, view, procedure, function
# - Sample data (optional - may need IDENTITY_INSERT adjustment)
```

Verify setup:

```sql
-- Check synonyms
SELECT name, base_object_name FROM sys.synonyms;
-- Should show: syn_Employees, syn_ActiveEmployees, syn_TestRecords, syn_ExternalTable

-- Check schemas
SELECT name FROM sys.schemas WHERE name IN ('dbo', 'hr');
-- Should show: dbo, hr

-- Check hr schema objects
SELECT name, type_desc FROM sys.objects WHERE schema_id = SCHEMA_ID('hr');
-- Should show: Benefits, vw_BenefitsWithDept, usp_GetBenefitsByType, fn_GetBenefitCount
```

## Automated Tests

### Running Automated Tests

1. Open Neovim
2. Load the test script:
   ```vim
   :e C:\Users\ShiFt\AppData\Local\nvim-data\lazy\vim-dadbod-ui\test_intellisense_manual.vim
   :source %
   ```
3. Run the tests:
   ```vim
   :call RunIntelliSenseTests()
   ```

### Automated Test Coverage

The automated tests verify:

1. ✓ DBUI connection exists
2. ✓ SSMS style enabled in config
3. ✓ Synonyms in object types config
4. ✓ Lazy loading enabled
5. ✓ Unified cache enabled
6. ✓ Completion module loaded
7. ✓ Schemas module has synonym query function
8. ✓ DBUI can open
9. ✓ Cache can be cleared
10. ✓ Blink.cmp source loaded (if using Neovim)

### Expected Output

```
=== Comprehensive IntelliSense Test Suite ===

✓ PASS: Verify DBUI connection exists
✓ PASS: SSMS style enabled in config
✓ PASS: Synonyms in g:db_ui_ssms_object_types
✓ PASS: Lazy loading enabled
✓ PASS: Unified cache enabled
✓ PASS: Completion module loaded
✓ PASS: Schemas module has synonym query function
✓ PASS: DBUI can open
✓ PASS: Cache can be cleared
✓ PASS: Blink.cmp source loaded

=== Test Summary ===
Total tests: 10
Passed: 10
Failed: 0
Success rate: 100.0%

✅ All automated tests passed!
```

## Manual Test Scenarios

Manual testing is required to verify IntelliSense completion behavior, which cannot be fully automated.

### Scenario 1: Synonym Resolution in DBUI Tree

**Purpose**: Verify synonyms appear in the DBUI tree structure.

**Steps**:
1. Open DBUI: `:DBUI`
2. Expand your server connection (`sqlserver://localhost`)
3. Expand `vim_dadbod_test` database
4. Look for `SYNONYMS` section (should be visible alongside TABLES, VIEWS, etc.)
5. Expand `SYNONYMS`

**Expected**:
- SYNONYMS section exists
- Shows 4 synonyms:
  - `syn_Employees`
  - `syn_ActiveEmployees`
  - `syn_TestRecords`
  - `syn_ExternalTable`

**Pass Criteria**: ✅ All 4 synonyms visible in tree

---

### Scenario 2: Synonym IntelliSense - Direct Synonym

**Purpose**: Verify IntelliSense resolves synonym to target table columns.

**Steps**:
1. Create a new query buffer: `:call CreateTestQueryBuffer()`
2. Type: `SELECT * FROM syn_Employees.`
3. Trigger completion (usually Ctrl+Space or auto-triggers after `.`)
4. Observe completion list

**Expected**:
- IntelliSense shows columns from `dbo.Employees` table:
  - EmployeeID
  - FirstName
  - LastName
  - DepartmentID
  - Email
  - HireDate
  - Salary
  - IsActive

**Pass Criteria**: ✅ Completion shows Employees table columns (8 columns)

---

### Scenario 3: Synonym IntelliSense - View Synonym

**Purpose**: Verify synonym resolution works for views.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM syn_ActiveEmployees.`
3. Trigger completion

**Expected**:
- IntelliSense shows columns from `dbo.vw_ActiveEmployees` view:
  - EmployeeID
  - FirstName
  - LastName
  - DepartmentID
  - Email
  - HireDate
  - Salary

**Pass Criteria**: ✅ Completion shows view columns (7 columns, IsActive excluded)

---

### Scenario 4: Synonym IntelliSense - Cross-Database Synonym

**Purpose**: Verify cross-database synonym resolution.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM syn_TestRecords.`
3. Trigger completion

**Expected**:
- IntelliSense shows columns from `TEST.dbo.Records` table:
  - ID
  - Name
  - Value
  - CreatedDate

**Pass Criteria**: ✅ Completion shows Records table columns from TEST database

---

### Scenario 5: External Database - All Object Types

**Purpose**: Verify all object types load when referencing external database.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM TEST.dbo.`
3. Trigger completion

**Expected**:
- IntelliSense shows all object types in `TEST.dbo`:
  - **Tables**: Records
  - **Views**: (if any)
  - **Procedures**: (if any)
  - **Functions**: (if any)
- All types should be loaded, not just tables

**Pass Criteria**: ✅ Completion shows at least Records table, and system attempts to load other object types

---

### Scenario 6: Schema Objects - All Types

**Purpose**: Verify all object types show when completing schema.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM dbo.`
3. Trigger completion

**Expected**:
- IntelliSense shows all object types:
  - **Tables**: Employees, Departments, Projects, test_table, newTable
  - **Views**: vw_ActiveEmployees, vw_DepartmentSummary, vw_ProjectStatus
  - **Procedures**: usp_GetEmployeesByDepartment, etc.
  - **Functions**: fn_GetFullName, etc.
  - **Synonyms**: syn_Employees, syn_ActiveEmployees, syn_TestRecords, syn_ExternalTable

**Pass Criteria**: ✅ Completion shows mix of all object types (15+ items)

---

### Scenario 7: Database List

**Purpose**: Verify database-level completion.

**Steps**:
1. In a query buffer connected to server (`sqlserver://localhost`)
2. Type: `SELECT * FROM vim`
3. Trigger completion

**Expected**:
- IntelliSense shows databases starting with "vim":
  - vim_dadbod_test

**Pass Criteria**: ✅ Completion shows vim_dadbod_test

---

### Scenario 8: Schema List After Database

**Purpose**: Verify schema completion after database name.

**Steps**:
1. In a query buffer
2. Type: `SELECT * FROM vim_dadbod_test.`
3. Trigger completion

**Expected**:
- IntelliSense shows schemas:
  - dbo
  - hr

**Pass Criteria**: ✅ Completion shows both dbo and hr schemas

---

### Scenario 9: Cross-Database Object Access

**Purpose**: Verify column completion for cross-database references.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM TEST.dbo.Records.`
3. Trigger completion

**Expected**:
- IntelliSense shows columns from `TEST.dbo.Records`:
  - ID
  - Name
  - Value
  - CreatedDate

**Pass Criteria**: ✅ Completion shows Records columns from external database

---

### Scenario 10: HR Schema Objects

**Purpose**: Verify multi-schema support.

**Steps**:
1. In a query buffer connected to `vim_dadbod_test`
2. Type: `SELECT * FROM hr.`
3. Trigger completion

**Expected**:
- IntelliSense shows hr schema objects:
  - **Tables**: Benefits
  - **Views**: vw_BenefitsWithDept
  - **Procedures**: usp_GetBenefitsByType
  - **Functions**: fn_GetBenefitCount

**Pass Criteria**: ✅ Completion shows all hr schema object types (4+ items)

---

### Scenario 11: Lazy Loading Performance

**Purpose**: Verify lazy loading doesn't load everything upfront.

**Steps**:
1. Clear cache: `:DBUIClearCache`
2. Restart Neovim
3. Open DBUI: `:DBUI`
4. Observe: Database tree should show databases but not expanded
5. In query buffer, type: `SELECT * FROM TEST.dbo.`
6. Observe: TEST database objects load on-demand

**Expected**:
- Tree doesn't auto-expand everything
- Objects load when referenced in query
- No significant delay when typing

**Pass Criteria**: ✅ Fast response time, objects load on-demand

---

### Scenario 12: Cache Persistence

**Purpose**: Verify cache improves performance on subsequent completions.

**Steps**:
1. Type: `SELECT * FROM dbo.Employees.` (first time - may be slower)
2. Observe completion time
3. Type it again in a new line
4. Observe completion time (should be faster)

**Expected**:
- First completion: May take 100-500ms (depends on network/server)
- Second completion: Should be nearly instant (< 50ms)

**Pass Criteria**: ✅ Cached completions are noticeably faster

---

## Expected Results Summary

### Completion Counts

Based on your SQL Server setup:

| Context | Expected Items | Object Types |
|---------|---------------|--------------|
| `dbo.` | 15+ | tables, views, procedures, functions, synonyms |
| `hr.` | 4+ | table, view, procedure, function |
| `TEST.dbo.` | 1+ | tables (at minimum) |
| `syn_Employees.` | 8 | columns from Employees |
| `syn_ActiveEmployees.` | 7 | columns from vw_ActiveEmployees |
| `syn_TestRecords.` | 4 | columns from TEST.dbo.Records |

### Tree Structure

Expected DBUI tree structure for `vim_dadbod_test`:

```
📁 sqlserver://localhost
  📁 vim_dadbod_test
    📁 TABLES (6)
      📄 Employees
      📄 Departments
      📄 Projects
      📄 test_table
      📄 newTable
    📁 VIEWS (4)
      📄 vw_ActiveEmployees
      📄 vw_DepartmentSummary
      📄 vw_ProjectStatus
    📁 PROCEDURES (6)
      📄 usp_GetEmployeesByDepartment
      📄 usp_GetDepartmentSummary
      ...
    📁 FUNCTIONS (5)
      📄 fn_GetFullName
      📄 fn_GetEmployeeCount
      ...
    📁 SYNONYMS (4)
      📄 syn_Employees
      📄 syn_ActiveEmployees
      📄 syn_TestRecords
      📄 syn_ExternalTable
```

## Troubleshooting

### Issue: Synonyms don't appear in DBUI tree

**Possible Causes**:
1. `g:db_ui_ssms_object_types` doesn't include 'synonyms'
2. DBUI cache is stale

**Solutions**:
```vim
" Verify config
:echo g:db_ui_ssms_object_types
" Should include 'synonyms'

" Clear cache and reload
:DBUIClearCache
:DBUIToggle
:DBUIToggle
```

---

### Issue: Synonym IntelliSense not working

**Possible Causes**:
1. `g:db_ui_intellisense_resolve_synonyms` is disabled
2. Synonym not loaded in cache
3. Blink.cmp source not configured

**Solutions**:
```vim
" Verify config
:echo g:db_ui_intellisense_resolve_synonyms
" Should be 1

" Verify blink.cmp source
:lua print(vim.inspect(require('blink.cmp').get_sources()))
" Should include 'dadbod'

" Clear cache
:DBUIClearCache
```

---

### Issue: External database objects not loading

**Possible Causes**:
1. `g:db_ui_intellisense_lazy_load` is disabled
2. Cache not triggering external DB load
3. Connection issue to external database

**Solutions**:
```vim
" Verify config
:echo g:db_ui_intellisense_lazy_load
" Should be 1

" Manually expand external DB in DBUI
:DBUI
" Navigate to TEST database and expand it

" Try completion again
```

---

### Issue: Slow completion performance

**Possible Causes**:
1. Cache disabled or TTL too short
2. Large database with many objects
3. Network latency to SQL Server

**Solutions**:
```vim
" Verify cache enabled
:echo g:db_ui_cache_enabled
" Should be 1

" Check cache TTL
:echo g:db_ui_cache_ttl
" Should be 300 (5 minutes) or higher

" Increase TTL for slower networks
let g:db_ui_cache_ttl = 600  " 10 minutes
```

---

### Issue: No completions at all

**Possible Causes**:
1. blink.cmp not configured
2. Database connection issue
3. Buffer not associated with database

**Solutions**:
```vim
" Check buffer connection
:echo b:dbui_db_key_name
" Should show connection string

" Check database connection
:echo db_ui#get_conn_info(b:dbui_db_key_name)
" Should show connection info

" Manually set connection
:DBUIChangeConnection
" Select vim_dadbod_test
```

---

### Debug Mode

Enable debug logging to troubleshoot issues:

```vim
" Enable debug
let g:db_ui_intellisense_debug = 1

" Type a query and trigger completion
" Check messages
:messages

" Look for debug output showing:
" - Hierarchical context resolution
" - Cache hits/misses
" - Synonym resolution
" - Object loading
```

---

## Performance Benchmarks

Expected performance on typical hardware (i5/i7, SSD, local SQL Server):

| Operation | First Time (Cold) | Cached (Warm) |
|-----------|-------------------|---------------|
| Load database list | 100-300ms | < 50ms |
| Load schema list | 50-150ms | < 20ms |
| Load objects (dbo.) | 200-500ms | < 50ms |
| Load columns | 100-300ms | < 30ms |
| Resolve synonym | N/A (uses cache) | < 10ms |
| External DB load | 200-500ms | < 50ms |

**Notes**:
- Cold times vary based on SQL Server performance
- Warm times should be nearly instant due to caching
- External DB loads are lazily triggered (only when referenced)

---

## Test Completion Checklist

Use this checklist to track your testing progress:

- [ ] Automated tests pass (10/10)
- [ ] Scenario 1: Synonyms in DBUI tree
- [ ] Scenario 2: Synonym to table columns
- [ ] Scenario 3: Synonym to view columns
- [ ] Scenario 4: Cross-database synonym
- [ ] Scenario 5: External DB all object types
- [ ] Scenario 6: Schema all object types
- [ ] Scenario 7: Database list
- [ ] Scenario 8: Schema list after database
- [ ] Scenario 9: Cross-database object columns
- [ ] Scenario 10: HR schema objects
- [ ] Scenario 11: Lazy loading performance
- [ ] Scenario 12: Cache persistence

**All tests passed**: 🎉 IntelliSense is working correctly!

**Some tests failed**: Review troubleshooting section and re-test.

---

## Reporting Issues

If you encounter issues not covered in this guide:

1. Enable debug mode: `let g:db_ui_intellisense_debug = 1`
2. Reproduce the issue
3. Capture messages: `:messages`
4. Check cache state: `:DBUIClearCache` and retry
5. Document:
   - What you typed
   - Expected vs actual completion
   - Debug messages
   - Configuration values

---

## Additional Resources

- **UNIFIED_CACHE_DESIGN.md**: Architecture details
- **UNIFIED_CACHE_IMPLEMENTATION.md**: Implementation summary
- **SYNONYMS_AND_ALL_OBJECTS_LOADING.md**: Synonym feature guide
- **CLAUDE.md**: Project overview and development guide

---

**Last Updated**: 2025-11-10
**Version**: Phase 1-5 Complete with Unified Cache
