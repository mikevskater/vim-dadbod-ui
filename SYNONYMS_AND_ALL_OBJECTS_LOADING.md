# Synonyms & All Objects Loading Implementation

## Summary of Enhancements

### 1. Load All Object Types (Not Just Tables) ✅

**Problem**: When user typed `OtherDB.dbo.`, only tables were loading. Views, procedures, functions, and synonyms were not available for completion.

**Solution**: Updated hierarchical resolution to load ALL object types when external database is referenced.

**File**: `autoload/db_ui/completion.vim` (lines 1555-1559)

**Changes**:
```vim
" Before (only tables):
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'tables')

" After (all objects):
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'tables')
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'views')
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'procedures')
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'functions')
call db_ui#completion#ensure_external_db_objects(a:db_key_name, a:parts[0], 'synonyms')
```

**Result**: When user types `OtherDB.dbo.`, ALL objects from that schema are now loaded and available for completion!

---

### 2. SQL Server Synonyms Support ✅

Implemented complete synonym support for SQL Server, including:
- Synonym metadata queries
- DBUI tree display
- IntelliSense completion
- Automatic synonym resolution

---

## Implementation Details

### A. SQL Server Synonym Query

**File**: `autoload/db_ui/schemas.vim`

**Line 246-249**: Added synonym query
```vim
let s:sqlserver_synonyms_query = "
      \ SELECT SCHEMA_NAME(schema_id) as schema_name, name as synonym_name, base_object_name
      \ FROM sys.synonyms
      \ ORDER BY schema_name, name"
```

**Line 318**: Added to sqlserver schema definition
```vim
\   'synonyms_query': trim(s:sqlserver_synonyms_query),
```

**What It Queries**: `sys.synonyms` system table
- `schema_name` - Schema the synonym belongs to
- `synonym_name` - Name of the synonym
- `base_object_name` - What the synonym points to (could be DB.schema.table or schema.table)

---

### B. Synonym Query Function

**File**: `autoload/db_ui/schemas.vim` (lines 790-821)

```vim
function! db_ui#schemas#query_synonyms(db, scheme) abort
  let query = get(a:scheme, 'synonyms_query', '')
  if empty(query)
    return []
  endif

  " Get raw results
  let raw_results = db_ui#schemas#query(a:db, a:scheme, query)

  " Parse as 3 columns: schema_name, synonym_name, base_object_name
  if a:scheme.synonyms_query =~? 'schema_name'
    let parsed = a:scheme.parse_results(raw_results, 3)
    let items = []
    for row in parsed
      if len(row) >= 3
        let schema_name = row[0]
        let synonym_name = row[1]
        let base_object_name = row[2]
        call add(items, {
              \ 'name': synonym_name,
              \ 'schema': schema_name,
              \ 'type': 'synonym',
              \ 'base_object': base_object_name
              \ })
      endif
    endfor
    return items
  else
    " Single column result - just synonym names
    return raw_results
  endif
endfunction
```

**Returns**: Array of synonym objects:
```vim
[
  {
    'name': 'MySynonym',
    'schema': 'dbo',
    'type': 'synonym',
    'base_object': 'OtherDB.dbo.RealTable'
  },
  ...
]
```

---

### C. DBUI Tree Structure Updates

#### 1. Added to Default Object Types

**File**: `plugin/db_ui.vim` (line 40)

```vim
" Before:
let g:db_ui_ssms_object_types = get(g:, 'db_ui_ssms_object_types', ['tables', 'views', 'procedures', 'functions'])

" After:
let g:db_ui_ssms_object_types = get(g:, 'db_ui_ssms_object_types', ['tables', 'views', 'procedures', 'functions', 'synonyms'])
```

#### 2. Added to Database Structure (Database-Level Connections)

**File**: `autoload/db_ui.vim` (lines 392-397)

```vim
if g:db_ui_use_ssms_style && !get(db, 'is_server', 0)
  let db.object_types = {
        \ 'views': {'expanded': 0, 'items': {}, 'list': []},
        \ 'procedures': {'expanded': 0, 'items': {}, 'list': []},
        \ 'functions': {'expanded': 0, 'items': {}, 'list': []},
        \ 'synonyms': {'expanded': 0, 'items': {}, 'list': []},  " ← Added
        \ }
endif
```

#### 3. Added to Server-Level Database Structure

**File**: `autoload/db_ui.vim` (lines 655-660)

```vim
\ 'object_types': {
\   'tables': {'expanded': 0, 'items': {}, 'list': []},
\   'views': {'expanded': 0, 'items': {}, 'list': []},
\   'procedures': {'expanded': 0, 'items': {}, 'list': []},
\   'functions': {'expanded': 0, 'items': {}, 'list': []},
\   'synonyms': {'expanded': 0, 'items': {}, 'list': []},  " ← Added
\ },
```

#### 4. Added Tree Rendering

**File**: `autoload/db_ui/drawer.vim` (lines 556-557)

```vim
function! s:drawer.render_object_types(server, database, level) abort
  for object_type in g:db_ui_ssms_object_types
    if object_type ==# 'tables'
      call self.render_object_type_group(a:server, a:database, 'TABLES', 'tables', a:database.tables, a:level)
    elseif object_type ==# 'views'
      call self.render_object_type_group(a:server, a:database, 'VIEWS', 'views', a:database.object_types.views, a:level)
    elseif object_type ==# 'procedures'
      call self.render_object_type_group(a:server, a:database, 'PROCEDURES', 'procedures', a:database.object_types.procedures, a:level)
    elseif object_type ==# 'functions'
      call self.render_object_type_group(a:server, a:database, 'FUNCTIONS', 'functions', a:database.object_types.functions, a:level)
    elseif object_type ==# 'synonyms'  " ← Added
      call self.render_object_type_group(a:server, a:database, 'SYNONYMS', 'synonyms', a:database.object_types.synonyms, a:level)
    endif
  endfor
endfunction
```

**Result**: DBUI tree now shows SYNONYMS section when expanded!

```
▾  MyDatabase
   ▾  TABLES (15)
   ▾  VIEWS (5)
   ▾  PROCEDURES (20)
   ▾  FUNCTIONS (8)
   ▾  SYNONYMS (12)       ← New section!
      MySynonym
      OtherSynonym
      ...
```

---

### D. Completion Cache Accessors

**File**: `autoload/db_ui/completion.vim` (lines 198-223)

```vim
" Get synonyms from DBUI cache
function! s:get_synonyms_from_dbui(db_key_name, ...) abort
  let external_db = get(a:, 1, '')
  let db = s:get_dbui_database(a:db_key_name)
  if empty(db)
    return []
  endif

  if !empty(external_db) && has_key(db, 'databases')
    if !has_key(db.databases.items, external_db)
      return []
    endif
    let target_db = db.databases.items[external_db]
  else
    let target_db = db
  endif

  if has_key(target_db, 'object_types') && has_key(target_db.object_types, 'synonyms')
    return get(target_db.object_types.synonyms, 'list', [])
  else
    return []
  endif
endfunction
```

---

### E. Synonym Resolution

**File**: `autoload/db_ui/completion.vim` (lines 225-280)

#### Function: `s:resolve_synonym(db_key_name, synonym_name)`

**Purpose**: Resolves a synonym to its target object (database, schema, table)

```vim
function! s:resolve_synonym(db_key_name, synonym_name) abort
  let synonyms = s:get_synonyms_from_dbui(a:db_key_name)
  for syn in synonyms
    if type(syn) == type({})
      let syn_name = get(syn, 'name', '')
      if syn_name ==? a:synonym_name
        let base_object = get(syn, 'base_object', '')
        if !empty(base_object)
          " Parse base_object: could be "DB.schema.table" or "schema.table" or "table"
          let parts = split(base_object, '\.')
          let result = {'database': '', 'schema': '', 'table': ''}

          if len(parts) == 3
            " DB.schema.table
            let result.database = trim(parts[0], '[]')
            let result.schema = trim(parts[1], '[]')
            let result.table = trim(parts[2], '[]')
          elseif len(parts) == 2
            " schema.table
            let result.schema = trim(parts[0], '[]')
            let result.table = trim(parts[1], '[]')
          elseif len(parts) == 1
            " just table (use default schema)
            let result.table = trim(parts[0], '[]')
          endif

          return result
        endif
      endif
    endif
  endfor
  return {}
endfunction
```

**Handles 3 formats**:
1. `OtherDB.dbo.Employees` → `{database: 'OtherDB', schema: 'dbo', table: 'Employees'}`
2. `dbo.Employees` → `{database: '', schema: 'dbo', table: 'Employees'}`
3. `Employees` → `{database: '', schema: '', table: 'Employees'}`

#### Function: `s:is_synonym(db_key_name, identifier)`

**Purpose**: Check if an identifier is a synonym

```vim
function! s:is_synonym(db_key_name, identifier) abort
  let synonyms = s:get_synonyms_from_dbui(a:db_key_name)
  for syn in synonyms
    if type(syn) == type({})
      let syn_name = get(syn, 'name', '')
      if syn_name ==? a:identifier
        return 1
      endif
    elseif syn ==? a:identifier
      return 1
    endif
  endfor
  return 0
endfunction
```

---

### F. Hierarchical Resolution with Synonym Support

**File**: `autoload/db_ui/completion.vim` (lines 1564-1578)

**Updated 2-part identifier handling** to check for synonyms:

```vim
if num_parts == 2
  " word1.word2 - Check hierarchically:
  " 1. Is word1 a database? → schemas
  " 2. Is word1 a synonym? → resolve and show columns  ← NEW!
  " 3. Is word1 a schema? → tables
  " 4. Is word1 a table? → columns

  if s:is_database(a:db_key_name, a:parts[0])
    " ...database handling
  elseif s:is_synonym(a:db_key_name, a:parts[0])
    " NEW: Synonym resolution
    let synonym_target = s:resolve_synonym(a:db_key_name, a:parts[0])
    if !empty(synonym_target) && !empty(synonym_target.table)
      " Synonym resolved successfully - show columns from target table
      let context.type = 'column'
      let context.database = synonym_target.database
      let context.schema = synonym_target.schema
      let context.table = synonym_target.table
      call s:debug('Hierarchical: ' . a:parts[0] . ' is synonym pointing to ' . synonym_target.table . ', showing columns')
    else
      " Couldn't resolve synonym
      let context.type = 'unknown'
    endif
  elseif s:is_schema(a:db_key_name, a:parts[0])
    " ...schema handling
  endif
endif
```

---

## How It Works: Complete Flow

### Scenario 1: User Types `MySynonym.`

**Setup**:
- Current database: `MyDB`
- Synonym: `MySynonym` → Points to `OtherDB.dbo.Employees`

**Flow**:

1. **User types `MySynonym.`**
2. **Detection**: `\w\+\.$` pattern matches
3. **Hierarchical check**:
   - `is_database('MySynonym')` → No
   - `is_synonym('MySynonym')` → **Yes!**
4. **Resolution**: `resolve_synonym('MySynonym')`
   - Returns: `{database: 'OtherDB', schema: 'dbo', table: 'Employees'}`
5. **Context**: `{type: 'column', database: 'OtherDB', schema: 'dbo', table: 'Employees'}`
6. **Completion fetches**: Columns from `OtherDB.dbo.Employees`
7. **User sees**: Column list from the real table!

**Result**: Typing `MySynonym.` shows columns from `OtherDB.dbo.Employees` ✅

---

### Scenario 2: User Types `OtherDB.dbo.M` (Shows All Objects)

**Flow**:

1. **User types `OtherDB.dbo.`**
2. **Detection**: `\w\+\.\w\+\.$` pattern (3-part)
3. **Hierarchical check**:
   - `is_database('OtherDB')` → **Yes**
4. **Triggers lazy loading**:
   ```vim
   call ensure_external_db_objects('OtherDB', 'tables')
   call ensure_external_db_objects('OtherDB', 'views')
   call ensure_external_db_objects('OtherDB', 'procedures')
   call ensure_external_db_objects('OtherDB', 'functions')
   call ensure_external_db_objects('OtherDB', 'synonyms')
   ```
5. **Loads ALL objects** via DBUI populate functions
6. **User types `M`**
7. **Completion shows**:
   - Tables starting with "M"
   - Views starting with "M"
   - Procedures starting with "M"
   - Functions starting with "M"
   - Synonyms starting with "M"

**Result**: All object types are available for completion! ✅

---

## Configuration

### Enable/Disable Synonyms

```vim
" Show synonyms in DBUI tree (default: enabled)
let g:db_ui_ssms_object_types = ['tables', 'views', 'procedures', 'functions', 'synonyms']

" Hide synonyms if you don't use them:
let g:db_ui_ssms_object_types = ['tables', 'views', 'procedures', 'functions']
```

### Enable Debug Output

```vim
:call db_ui#completion#toggle_debug()
```

**Look for in `:messages`**:
```
[db_ui_completion] Hierarchical: MySynonym is synonym pointing to Employees, showing columns
[db_ui_completion] Triggering granular load: OtherDB.synonyms
[db_ui_completion] Successfully loaded: OtherDB.synonyms (12 items)
```

---

## Testing Checklist

### Synonym Resolution:
- [ ] Create a synonym pointing to a table: `CREATE SYNONYM MySyn FOR dbo.MyTable`
- [ ] Type `MySyn.` → verify column completion shows
- [ ] Verify columns are from the target table
- [ ] Create synonym pointing to external DB: `CREATE SYNONYM ExtSyn FOR OtherDB.dbo.Table`
- [ ] Type `ExtSyn.` → verify external DB table columns show

### Tree Display:
- [ ] Open DBUI tree
- [ ] Expand database → verify SYNONYMS section appears
- [ ] Expand SYNONYMS → verify synonym list shows
- [ ] Verify synonym names are correct

### All Objects Loading:
- [ ] Type `OtherDB.dbo.` where OtherDB is external
- [ ] Verify loading notifications appear for all object types
- [ ] Type `OtherDB.dbo.M` → verify completion shows tables, views, procedures, functions, AND synonyms
- [ ] Verify filtering works (only items starting with "M")

### Performance:
- [ ] Database with 100+ synonyms
- [ ] Verify first load takes a moment
- [ ] Type same pattern again → verify instant (cached)
- [ ] Expand tree → verify already loaded (no re-fetch)

---

## Files Modified

1. **`autoload/db_ui/schemas.vim`**
   - Lines 246-249: Added synonym query definition
   - Line 318: Added to sqlserver schema
   - Lines 790-821: Created `query_synonyms()` function

2. **`plugin/db_ui.vim`**
   - Line 40: Added 'synonyms' to default object types list

3. **`autoload/db_ui.vim`**
   - Line 396: Added synonyms to database object_types structure
   - Line 660: Added synonyms to server-level database structure

4. **`autoload/db_ui/drawer.vim`**
   - Lines 556-557: Added synonym rendering to tree

5. **`autoload/db_ui/completion.vim`**
   - Lines 198-223: Added `get_synonyms_from_dbui()` accessor
   - Lines 225-280: Added `resolve_synonym()` and `is_synonym()` functions
   - Lines 1555-1559: Updated to load all object types (added synonyms)
   - Lines 1564-1578: Added synonym resolution to hierarchical context

---

## Summary

### ✅ Load All Object Types
When user types `OtherDB.dbo.`, the system now loads:
- Tables
- Views
- Procedures
- Functions
- Synonyms

All available for completion!

### ✅ Synonyms Support
- SQL Server synonym metadata queries
- DBUI tree display with SYNONYMS section
- Synonym resolution: `MySynonym.` → Shows columns from target table
- Handles 3 formats: `DB.schema.table`, `schema.table`, `table`
- Works with external database references

### ✅ Unified with DBUI Tree
- Tree expansion loads synonyms
- IntelliSense triggers load synonyms
- Both share the same cache

**Result**: Complete SSMS-style IntelliSense with synonym support! 🎉
