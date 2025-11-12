# Unified Cache Architecture

## Problem Statement

Currently, there are **two separate caches** for database metadata:

1. **DBUI Tree Cache** (`autoload/db_ui.vim`) - Used by the UI tree drawer
2. **Completion Cache** (`autoload/db_ui/completion.vim`) - Used by IntelliSense

This creates:
- ❌ **Data duplication** - Same metadata stored twice
- ❌ **Synchronization issues** - Changes in one cache don't reflect in the other
- ❌ **Wasted memory** - Storing identical data in two places
- ❌ **Inconsistent behavior** - Tree expansion doesn't populate IntelliSense, vice versa

---

## Solution: Unified Cache with Direct Access

**Make DBUI cache the single source of truth.** IntelliSense reads directly from DBUI cache instead of duplicating data.

---

## DBUI Cache Structure

### Server-Level Connection

```vim
server = {
  'name': 'MyServer',
  'key_name': 'MyServer_g:dbs',
  'is_server': 1,
  'scheme': 'sqlserver',
  'conn': <connection>,
  'databases': {
    'expanded': 0,
    'list': ['DB1', 'DB2', 'DB3'],
    'items': {
      'DB1': {
        'name': 'DB1',
        'url': 'sqlserver://localhost/DB1',
        'conn': <connection>,
        'expanded': 0,
        'object_types': {
          'tables': {
            'expanded': 0,
            'list': ['[dbo].[Employees]', '[dbo].[Departments]'],
            'items': {
              '[dbo].[Employees]': {
                'name': 'Employees',
                'schema': 'dbo',
                'full_name': '[dbo].[Employees]',
                'expanded': 0,
                'structural_groups': {
                  'columns': {'expanded': 0, 'data': [...]},
                  'indexes': {'expanded': 0, 'data': [...]},
                  'primary_keys': {'expanded': 0, 'data': [...]},
                }
              }
            }
          },
          'views': {'expanded': 0, 'list': [...], 'items': {...}},
          'procedures': {'expanded': 0, 'list': [...], 'items': {...}},
          'functions': {'expanded': 0, 'list': [...], 'items': {...}}
        },
        'schemas': {
          'expanded': 0,
          'list': ['dbo', 'hr', 'sales'],
          'items': {
            'dbo': {
              'tables': {'list': [...], 'items': {...}},
              'views': {...}
            }
          }
        },
        'tables': {'expanded': 0, 'list': [...], 'items': {...}}
      },
      'DB2': {...}
    }
  }
}
```

### Database-Level Connection

```vim
db = {
  'name': 'MyDB',
  'key_name': 'MyDB_g:dbs',
  'is_server': 0,
  'scheme': 'sqlserver',
  'conn': <connection>,
  'tables': {
    'expanded': 0,
    'list': ['[dbo].[Employees]', '[dbo].[Departments]'],
    'items': {
      '[dbo].[Employees]': {
        'name': 'Employees',
        'schema': 'dbo',
        'expanded': 0,
        'structural_groups': {
          'columns': {'expanded': 0, 'data': [...]},
        }
      }
    }
  },
  'schemas': {
    'expanded': 0,
    'list': ['dbo', 'hr'],
    'items': {...}
  },
  'object_types': {
    'tables': {...},
    'views': {...},
    'procedures': {...},
    'functions': {...}
  }
}
```

---

## Implementation Design

### 1. Add DBUI Instance Accessor

Create function to get DBUI instance from completion module:

```vim
" autoload/db_ui/completion.vim

" Get DBUI instance for accessing tree cache
" @return DBUI instance dictionary
function! s:get_dbui_instance() abort
  return db_ui#drawer#get().dbui
endfunction

" Get database entry from DBUI cache
" @param db_key_name - Database identifier
" @return Database dictionary from DBUI cache
function! s:get_dbui_database(db_key_name) abort
  let dbui = s:get_dbui_instance()
  if empty(dbui) || !has_key(dbui, 'dbs')
    return {}
  endif
  if !has_key(dbui.dbs, a:db_key_name)
    return {}
  endif
  return dbui.dbs[a:db_key_name]
endfunction
```

### 2. Create Cache Accessor Functions

Instead of maintaining separate cache, read directly from DBUI:

```vim
" Get tables from DBUI cache
" @param db_key_name - Database identifier
" @param external_db_name - Optional external database name
" @return List of table objects
function! s:get_tables_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  " If external DB specified, navigate to that database
  if !empty(external_db) && has_key(db, 'databases')
    " Server-level connection - get external database
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    " Current database
    let target_db = db
  endif

  " Get tables from object_types if SSMS mode, otherwise from tables
  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'tables')
    return get(target_db.object_types.tables, 'list', [])
  else
    return get(target_db.tables, 'list', [])
  endif
endfunction

" Similar functions for views, procedures, functions...
function! s:get_views_from_dbui(db_key_name, ...) abort
  " ... similar pattern
endfunction

function! s:get_procedures_from_dbui(db_key_name, ...) abort
  " ... similar pattern
endfunction

function! s:get_functions_from_dbui(db_key_name, ...) abort
  " ... similar pattern
endfunction
```

### 3. Lazy Loading with DBUI Populate Functions

When external database is referenced, use DBUI's populate functions:

```vim
" Ensure external database objects are loaded
" @param db_key_name - Server identifier
" @param db_name - External database name
" @param object_type - 'tables'|'views'|'procedures'|'functions'
" @return 1 if loaded or already available, 0 if failed
function! db_ui#completion#ensure_external_db_objects(db_key_name, db_name, object_type) abort
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db) || !has_key(db, 'databases')
    return 0
  endif

  " Check if database structure exists
  if !has_key(db.databases.items, a:db_name)
    call s:debug('Database not in server list: ' . a:db_name)
    return 0
  endif

  let target_db = db.databases.items[a:db_name]

  " Connect to database if not connected
  if empty(target_db.conn) && !target_db.conn_tried
    let dbui = s:get_dbui_instance()
    call dbui.connect_to_database(db, a:db_name)
  endif

  " Check if object type already loaded
  if has_key(target_db.object_types, a:object_type)
    let obj_cache = target_db.object_types[a:object_type]
    if obj_cache.expanded && !empty(obj_cache.list)
      call s:debug('Objects already loaded: ' . a:db_name . '.' . a:object_type)
      return 1
    endif
  endif

  " Trigger loading via DBUI drawer
  call s:debug('Triggering lazy load: ' . a:db_name . '.' . a:object_type)

  if get(g:, 'db_ui_show_loading_indicator', 1)
    call db_ui#notifications#info('Loading ' . a:db_name . ' ' . a:object_type . '...')
  endif

  let drawer = db_ui#drawer#get()
  if a:object_type ==# 'tables'
    call drawer.populate_tables(target_db)
  else
    let dbui = s:get_dbui_instance()
    let scheme_info = db_ui#schemas#get(target_db.scheme)
    call dbui.populate_object_type(target_db, a:object_type, scheme_info)
  endif

  " Mark as expanded so we don't re-fetch
  let target_db.object_types[a:object_type].expanded = 1

  return 1
endfunction
```

### 4. Granular Lazy Loading Triggers

Update hierarchical resolution to trigger granular loading:

```vim
" In resolve_hierarchical_context() - when 2-part identifier detected:

if s:is_database(db_key_name, parts[0])
  " External database reference - trigger lazy load for schemas only
  " Schemas are loaded automatically with databases list, no separate fetch needed

  if !has_trailing_content
    " User typed: "OtherDB." - suggest schemas
    let context.type = 'schema'
    let context.database = parts[0]
  else
    " User typing: "OtherDB.dbo" - filtering schemas
    let context.type = 'schema'
    let context.database = parts[0]
  endif
  return context
endif

" In resolve_hierarchical_context() - when 3-part identifier detected:

if s:is_database(db_key_name, parts[0])
  " Check if this is schema reference
  if s:is_schema_in_external_db(db_key_name, parts[0], parts[1])
    if !has_trailing_content
      " User typed: "OtherDB.dbo." - load tables for this schema
      call db_ui#completion#ensure_external_db_objects(db_key_name, parts[0], 'tables')

      let context.type = 'table'
      let context.database = parts[0]
      let context.schema = parts[1]
    else
      " User typing: "OtherDB.dbo.E" - tables already loaded, filter
      let context.type = 'table'
      let context.database = parts[0]
      let context.schema = parts[1]
    endif
  endif
  return context
endif
```

---

## Loading Sequence

### Scenario: User types `OtherDB.dbo.Employees`

#### Step 1: User types `OtherDB.`

**Detection:**
- Pattern: `\w\+\.$`
- Matched: "OtherDB."
- Check: `is_database('OtherDB')` → Yes

**Action:**
- Context type: `schema`
- Context database: `OtherDB`
- **No loading triggered** (schemas already in `databases.list`)

**Completion shows:** Schemas from OtherDB (dbo, hr, sales, etc.)

#### Step 2: User types `OtherDB.dbo.`

**Detection:**
- Pattern: `\w\+\.\w\+\.$`
- Matched: "OtherDB.dbo."
- Check: `is_database('OtherDB')` → Yes
- Check: `is_schema_in_db('OtherDB', 'dbo')` → Yes

**Action:**
- Context type: `table`
- Context database: `OtherDB`
- Context schema: `dbo`
- **Trigger lazy load**: `ensure_external_db_objects('server_key', 'OtherDB', 'tables')`
  - Calls `drawer.populate_tables(target_db)`
  - Fetches only tables from OtherDB
  - Stores in `databases.items['OtherDB'].object_types.tables.list`

**Completion shows:** Tables from OtherDB.dbo schema (loading... then results)

#### Step 3: User types `OtherDB.dbo.E`

**Detection:**
- Pattern: `\w\+\.\w\+\.\w+$`
- Context type: `table`
- Filter: "E"

**Action:**
- **No loading** (tables already cached from Step 2)
- Filter cached tables by partial match "E"

**Completion shows:** Tables starting with "E" (Employees, EmployeeHistory, etc.)

#### Step 4: User types `OtherDB.dbo.Employees.`

**Detection:**
- Pattern: `\w\+\.\w\+\.\w+\.$`
- Check: `is_table_in_db('OtherDB', 'dbo', 'Employees')` → Yes

**Action:**
- Context type: `column`
- Context database: `OtherDB`
- Context schema: `dbo`
- Context table: `Employees`
- **Trigger lazy load**: Load columns for this specific table

**Completion shows:** Columns from OtherDB.dbo.Employees

---

## Benefits

### ✅ Single Source of Truth
- DBUI cache is the only place metadata is stored
- No synchronization issues
- No duplicate data

### ✅ Bidirectional Integration
- **Tree → IntelliSense**: User expands tree → IntelliSense has data immediately
- **IntelliSense → Tree**: User types reference → Tree shows loaded data

### ✅ True Granular Loading
- **Databases**: Loaded once when server connection expanded
- **Schemas**: Available from database list (no separate fetch)
- **Tables**: Loaded when user types `DB.schema.` or expands tree node
- **Views/Procedures/Functions**: Loaded when user expands tree or references in query
- **Columns**: Loaded per-table when needed

### ✅ Memory Efficient
- Only loads what user actually uses
- Server with 100 databases, 1000 tables each?
  - Only fetches the 2-3 databases user references
  - Only fetches tables when schema is specified
  - **Not** pre-loading all 100,000 objects!

### ✅ Performance Optimized
- First reference: Slight delay while loading (async)
- Subsequent references: Instant (cached in DBUI)
- Cache persists for entire Vim session

---

## Migration Path

### Phase 1: Add Accessor Functions ✅
1. Create `s:get_dbui_instance()`
2. Create `s:get_dbui_database()`
3. Create `s:get_tables_from_dbui()` and siblings
4. Keep existing cache as fallback

### Phase 2: Implement Granular Loading ⏳
1. Create `ensure_external_db_objects()` function
2. Update hierarchical resolution to trigger granular loads
3. Add schema existence checks for external databases
4. Test loading sequence

### Phase 3: Remove Duplicate Cache ⏳
1. Deprecate `s:completion_cache` structure
2. Remove cache initialization code
3. Remove duplicate data storage
4. Keep only metadata (last_updated, ttl)

### Phase 4: Testing ⏳
1. Test tree expansion → IntelliSense populated
2. Test IntelliSense trigger → tree shows data
3. Test external database references
4. Test large databases (performance)

---

## Files to Modify

1. **`autoload/db_ui/completion.vim`**
   - Add accessor functions
   - Modify `init_cache()` to not duplicate data
   - Modify `ensure_external_db_cached()` to use DBUI populate functions
   - Update hierarchical resolution to trigger granular loads

2. **`autoload/db_ui.vim`**
   - Expose `get_dbui_instance()` if not already public
   - Ensure `connect_to_database()` is accessible
   - Ensure `populate_object_type()` is accessible

3. **`autoload/db_ui/drawer.vim`**
   - Ensure `populate_tables()` can be called from completion
   - Add `get_dbui()` accessor if needed

---

## Configuration Options

```vim
" Enable unified cache (default: 1)
let g:db_ui_intellisense_use_unified_cache = 1

" Enable lazy loading for external databases (default: 1)
let g:db_ui_intellisense_lazy_load = 1

" Show loading notifications (default: 1)
let g:db_ui_show_loading_indicator = 1
```

---

## Comparison: Before vs After

### Before (Duplicate Cache)

**User types `OtherDB.dbo.Employees`**:
1. `OtherDB.` → Fetch ALL objects from OtherDB (tables, views, procs, functions)
2. Store in `s:completion_cache[server].external_databases['OtherDB']`
3. Tree cache is separate - if user expands tree later, re-fetches same data

**Memory**: 2x storage (completion cache + tree cache)
**Loading**: Bulk loading (all objects at once)
**Consistency**: Changes in tree don't reflect in IntelliSense

### After (Unified Cache)

**User types `OtherDB.dbo.Employees`**:
1. `OtherDB.` → No loading (schemas already available)
2. `OtherDB.dbo.` → Fetch only tables from OtherDB
3. Store in `dbui.dbs[server].databases.items['OtherDB'].object_types.tables`
4. Both tree and IntelliSense read from same cache

**Memory**: 1x storage (DBUI cache only)
**Loading**: Granular loading (only tables when needed)
**Consistency**: Perfect synchronization

---

## Summary

**Goal**: Make IntelliSense and DBUI tree share the same cache.

**Method**: IntelliSense reads directly from DBUI cache instead of duplicating data.

**Result**: True SSMS-style granular lazy loading with unified state! 🚀
