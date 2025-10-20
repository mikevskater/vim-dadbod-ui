# vim-dadbod-ui Filter System Design

## Overview
This document outlines the comprehensive design for adding real-time filtering capabilities to vim-dadbod-ui's object lists. The filtering system will allow users to filter by schema name, object name, and column name (for tables) at each hierarchical level without affecting parent lists.

---

## 1. Requirements Analysis

### Core Requirements
1. **Multi-criteria filtering**: Schema name, object name, column name
2. **Independent filtering**: Each level filters independently (columns don't affect tables, tables don't affect procedures)
3. **Real-time filtering**: Filter cached lists immediately without re-querying
4. **Elegant UI**: Clear indication of active filters, easy to edit/clear
5. **Persistent state**: Filters remain active until explicitly cleared or drawer is closed

### User Workflows
- **Apply filter**: User presses key binding (e.g., `f` or `F`) on an object type group or object
- **Edit filter**: User can modify existing filter
- **Clear filter**: User can clear filter for current level or all filters
- **Visual feedback**: Active filters clearly shown with indicator and count

---

## 2. Architecture & State Management

### Filter State Structure
```vim
" Global filter storage (per database/object type)
let s:filters = {
  'server_key.database_name.tables': {
    'schema': '',      " Schema name filter (regex or plain text)
    'object': '',      " Object name filter
    'column': ''       " Column name filter (only for tables)
  },
  'server_key.database_name.views': {...},
  'server_key.database_name.procedures': {...},
  'server_key.database_name.functions': {...},
}

" Per-object filters for structural groups (columns, indexes, etc.)
let s:object_filters = {
  'server_key.database_name.tables.[dbo].[Employees].columns': {
    'column': ''       " Column name filter
  }
}
```

### Filter Scope Hierarchy
```
Server
└── Database
    ├── TABLES (object type level)
    │   ├── Filter: schema + object name
    │   └── [dbo].[Employees] (individual object)
    │       ├── Columns (structural group)
    │       │   └── Filter: column name
    │       ├── Indexes
    │       │   └── Filter: index name
    │       └── Keys
    │           └── Filter: key name
    ├── VIEWS (independent object type)
    │   └── Filter: schema + object name (independent from tables)
    ├── PROCEDURES
    │   └── Filter: schema + object name
    └── FUNCTIONS
        └── Filter: schema + object name
```

---

## 3. UI/UX Design

### Visual Indicators

#### Active Filter Display
```
▾  TABLES (342) 🔍 [schema:dbo, object:Employee*] (15 filtered)
    [Filter: schema=dbo, object=Employee*]  ← Filter status line
    ▸  [dbo].[Employees]
    ▸  [dbo].[EmployeeSalaries]
    ...

▾  VIEWS (50) 🔍 [object:vw_*] (3 filtered)  ← Independent filter
    [Filter: object=vw_*]
    ▸  [dbo].[vw_ActiveEmployees]
    ...
```

#### No Active Filter
```
▾  TABLES (342)
    ▸  [dbo].[Employees]
    ▸  [dbo].[Products]
    ...
```

#### Structural Group Filter (Columns)
```
▸  [dbo].[Employees]
▾  Columns 🔍 [name:*id] (3 filtered)
    [Filter: column=*id]
    EmployeeID | int | NULL | NO
    DepartmentID | int | NULL | YES
    ManagerID | int | NULL | YES
```

### Filter Input UI

When user presses filter key (e.g., `f`), show input prompt:

```vim
" For object type groups (TABLES, VIEWS, etc.)
Filter tables by: (s)chema, (o)bject, (b)oth, (c)lear: _

" If user selects 'b' (both)
Schema filter (regex): _
Object filter (regex): _

" If user selects 's' (schema only)
Schema filter (regex): _

" For structural groups (Columns, Indexes, etc.)
Filter columns by name (regex): _
```

### Key Bindings

| Key | Action | Context |
|-----|--------|---------|
| `f` | Apply/edit filter | On object type group or structural group |
| `F` | Clear filter for current level | On filtered group |
| `<leader>fc` | Clear all filters | Anywhere in drawer |
| `<leader>fs` | Show all active filters | Anywhere in drawer |

---

## 4. Implementation Plan

### Phase 1: Core Filter Infrastructure (Files: autoload/db_ui/filter.vim)

**Create new filter management module**

```vim
" autoload/db_ui/filter.vim

" Storage
let s:filters = {}          " Object type filters
let s:object_filters = {}   " Structural group filters

" Initialize filter for a scope
function! db_ui#filter#init(scope) abort
  " Creates empty filter structure
endfunction

" Set filter criteria
function! db_ui#filter#set(scope, criteria) abort
  " criteria: {'schema': 'dbo', 'object': 'Employee*', 'column': ''}
endfunction

" Get filter for scope
function! db_ui#filter#get(scope) abort
  " Returns filter dict or empty if none
endfunction

" Check if item matches filter
function! db_ui#filter#matches(item, filter) abort
  " Uses regex matching or plain text
  " Returns 1 if matches, 0 if filtered out
endfunction

" Clear filter for scope
function! db_ui#filter#clear(scope) abort
endfunction

" Clear all filters
function! db_ui#filter#clear_all() abort
endfunction

" Get all active filters
function! db_ui#filter#list_active() abort
  " Returns list of {scope, criteria} for display
endfunction

" Count items after filtering
function! db_ui#filter#count_matches(items, filter) abort
endfunction
```

### Phase 2: Drawer Integration (File: autoload/db_ui/drawer.vim)

**Modify rendering functions to apply filters**

```vim
" In render_object_type_group()
function! s:drawer.render_object_type_group(server, database, label, object_type, object_data, level) abort
  " 1. Get filter for this scope
  let scope = a:server.key_name . '.' . a:database.name . '.' . a:object_type
  let filter = db_ui#filter#get(scope)

  " 2. Apply filter to object_data.list
  let filtered_list = []
  if !empty(filter)
    for item in a:object_data.list
      if db_ui#filter#matches(item, filter)
        call add(filtered_list, item)
      endif
    endfor
  else
    let filtered_list = a:object_data.list
  endif

  " 3. Update label with filter indicator and count
  let count = len(filtered_list)
  let total = len(a:object_data.list)
  let filter_indicator = !empty(filter) ? ' 🔍 ' . s:format_filter(filter) : ''
  let count_str = !empty(filter) ? count . '/' . total : count
  let label = a:label . ' (' . count_str . ')' . filter_indicator

  " 4. Render filtered list
  " ... rest of rendering logic with filtered_list
endfunction

" Format filter for display
function! s:format_filter(filter) abort
  let parts = []
  if !empty(a:filter.schema)
    call add(parts, 'schema:' . a:filter.schema)
  endif
  if !empty(a:filter.object)
    call add(parts, 'object:' . a:filter.object)
  endif
  if !empty(a:filter.column)
    call add(parts, 'column:' . a:filter.column)
  endif
  return '[' . join(parts, ', ') . ']'
endfunction
```

**Modify structural group rendering**

```vim
" In render_structural_group_items()
function! s:drawer.render_structural_group_items(data, group_type, key_name, level) abort
  " 1. Get filter for this structural group
  let scope = ... " Build scope from context
  let filter = db_ui#filter#get(scope)

  " 2. Filter data
  let filtered_data = []
  if !empty(filter) && has_key(filter, 'column')
    for row in a:data
      " Match against column name (first field)
      if db_ui#filter#matches(row[0], {'object': filter.column})
        call add(filtered_data, row)
      endif
    endfor
  else
    let filtered_data = a:data
  endif

  " 3. Render filtered data
  " ... existing rendering logic
endfunction
```

### Phase 3: User Interaction (File: autoload/db_ui/drawer.vim)

**Add filter actions**

```vim
" Apply/edit filter
function! s:drawer.apply_filter() abort
  let item = self.get_current_item()

  " Determine scope and filter type
  if item.type ==? 'toggle' && has_key(item, 'object_type')
    " Object type group (TABLES, VIEWS, etc.)
    let scope = item.dbui_db_key_name . '.' . item.database_name . '.' . item.object_type
    call s:prompt_object_type_filter(scope)

  elseif item.type ==? 'structural_group'
    " Structural group (Columns, Indexes, etc.)
    let scope = item.dbui_db_key_name . '.' . item.database_name . '.' . item.object_type . '.' . item.object_name . '.' . item.group_type
    call s:prompt_structural_filter(scope, item.group_type)
  endif

  " Re-render after filter applied
  return self.render()
endfunction

" Prompt for object type filter (tables, views, etc.)
function! s:prompt_object_type_filter(scope) abort
  let existing = db_ui#filter#get(a:scope)

  " Ask what to filter by
  let choice = db_ui#utils#input('Filter by: (s)chema, (o)bject, (b)oth, (c)lear: ', '')

  if choice ==? 'c'
    call db_ui#filter#clear(a:scope)
    return
  endif

  let filter = {}

  if choice ==? 's' || choice ==? 'b'
    let filter.schema = db_ui#utils#input('Schema filter (regex): ', get(existing, 'schema', ''))
  endif

  if choice ==? 'o' || choice ==? 'b'
    let filter.object = db_ui#utils#input('Object filter (regex): ', get(existing, 'object', ''))
  endif

  call db_ui#filter#set(a:scope, filter)
endfunction

" Prompt for structural group filter
function! s:prompt_structural_filter(scope, group_type) abort
  let existing = db_ui#filter#get(a:scope)
  let label = a:group_type ==? 'columns' ? 'column' : a:group_type

  let filter_value = db_ui#utils#input('Filter ' . label . ' (regex): ', get(existing, 'column', ''))

  if empty(filter_value)
    call db_ui#filter#clear(a:scope)
  else
    call db_ui#filter#set(a:scope, {'column': filter_value})
  endif
endfunction

" Clear filter for current item
function! s:drawer.clear_filter() abort
  let item = self.get_current_item()

  if item.type ==? 'toggle' && has_key(item, 'object_type')
    let scope = item.dbui_db_key_name . '.' . item.database_name . '.' . item.object_type
    call db_ui#filter#clear(scope)
  elseif item.type ==? 'structural_group'
    let scope = item.dbui_db_key_name . '.' . item.database_name . '.' . item.object_type . '.' . item.object_name . '.' . item.group_type
    call db_ui#filter#clear(scope)
  endif

  return self.render()
endfunction

" Show all active filters
function! s:drawer.show_filters() abort
  let active = db_ui#filter#list_active()

  if empty(active)
    call db_ui#notifications#info('No active filters')
    return
  endif

  let messages = ['Active filters:']
  for item in active
    call add(messages, '  ' . item.scope . ': ' . string(item.criteria))
  endfor

  call db_ui#notifications#info(messages)
endfunction
```

**Add key mappings**

```vim
" In s:drawer.open()
nnoremap <silent><buffer> <Plug>(DBUI_ApplyFilter) :call <sid>method('apply_filter')<CR>
nnoremap <silent><buffer> <Plug>(DBUI_ClearFilter) :call <sid>method('clear_filter')<CR>
nnoremap <silent><buffer> <Plug>(DBUI_ClearAllFilters) :call <sid>method('clear_all_filters')<CR>
nnoremap <silent><buffer> <Plug>(DBUI_ShowFilters) :call <sid>method('show_filters')<CR>
```

### Phase 4: Configuration (File: plugin/db_ui.vim)

**Add configuration options**

```vim
" Filter key bindings (default)
let g:db_ui_filter_key = get(g:, 'db_ui_filter_key', 'f')
let g:db_ui_clear_filter_key = get(g:, 'db_ui_clear_filter_key', 'F')
let g:db_ui_clear_all_filters_key = get(g:, 'db_ui_clear_all_filters_key', '<leader>fc')
let g:db_ui_show_filters_key = get(g:, 'db_ui_show_filters_key', '<leader>fs')

" Filter behavior
let g:db_ui_filter_case_sensitive = get(g:, 'db_ui_filter_case_sensitive', 0)
let g:db_ui_filter_use_regex = get(g:, 'db_ui_filter_use_regex', 1)

" Visual indicators
let g:db_ui_filter_icon = get(g:, 'db_ui_filter_icon', '🔍')
```

### Phase 5: Regex Matching Implementation

**Implement smart pattern matching**

```vim
" In autoload/db_ui/filter.vim

function! db_ui#filter#matches(item, filter) abort
  " item: string (object name like '[dbo].[Employees]')
  " filter: dict with schema, object, column keys

  " Parse item to extract parts
  let parts = s:parse_item(a:item)

  " Check schema filter
  if has_key(a:filter, 'schema') && !empty(a:filter.schema)
    if !s:matches_pattern(parts.schema, a:filter.schema)
      return 0
    endif
  endif

  " Check object filter
  if has_key(a:filter, 'object') && !empty(a:filter.object)
    if !s:matches_pattern(parts.object, a:filter.object)
      return 0
    endif
  endif

  " Check column filter
  if has_key(a:filter, 'column') && !empty(a:filter.column)
    if !s:matches_pattern(parts.column, a:filter.column)
      return 0
    endif
  endif

  return 1
endfunction

function! s:matches_pattern(text, pattern) abort
  if g:db_ui_filter_use_regex
    " Use vim regex
    let flags = g:db_ui_filter_case_sensitive ? '' : '\c'
    return a:text =~# flags . a:pattern
  else
    " Plain text match
    if g:db_ui_filter_case_sensitive
      return stridx(a:text, a:pattern) >= 0
    else
      return stridx(tolower(a:text), tolower(a:pattern)) >= 0
    endif
  endif
endfunction

function! s:parse_item(item) abort
  " Parse '[schema].[object]' format
  let match_result = matchlist(a:item, '^\[\?\([^\]]*\)\]\?\.\[\?\([^\]]*\)\]\?$')

  if !empty(match_result) && len(match_result) >= 3
    return {
      \ 'schema': match_result[1],
      \ 'object': match_result[2],
      \ 'column': a:item
      \ }
  endif

  " Fallback for non-standard format
  return {
    \ 'schema': '',
    \ 'object': a:item,
    \ 'column': a:item
    \ }
endfunction
```

---

## 5. Testing Plan

### Test Scenarios

1. **Basic filtering**
   - Filter tables by schema name
   - Filter tables by object name
   - Filter views by object name
   - Verify independent filtering (tables vs views)

2. **Complex patterns**
   - Wildcard patterns: `*Employee*`, `vw_*`, `*_id`
   - Regex patterns: `^dbo\.`, `Employee(s|Data)`, `\d+`
   - Case sensitivity toggle

3. **Structural group filtering**
   - Filter columns by name
   - Filter indexes by name
   - Verify independence from parent object list

4. **UI/UX**
   - Filter indicator displays correctly
   - Filtered count accurate
   - Clear filter works
   - Clear all filters works

5. **Edge cases**
   - Empty filter (should show all)
   - Filter with no matches (should show empty)
   - Very large lists (performance)
   - Special characters in names

6. **State management**
   - Filters persist during navigation
   - Filters cleared when appropriate
   - Multiple filters coexist independently

---

## 6. Performance Considerations

### Caching & Optimization
- Filters work on **cached data** (no re-querying)
- Regex compilation cached per pattern
- Filtered results not re-filtered on re-render (unless filter changed)

### Large Dataset Handling
- Pagination still applies to filtered results
- Filter before pagination (filter 10,000 items → paginate 100 results)
- Consider showing "Filtering..." indicator for very large lists

### Memory Impact
- Filter state is minimal (just pattern strings)
- No duplication of data (filter references existing lists)

---

## 7. Documentation

### User Documentation (README.md)

```markdown
## Filtering Objects

vim-dadbod-ui supports real-time filtering of database objects at multiple levels.

### Quick Start

1. Navigate to an object type (TABLES, VIEWS, etc.)
2. Press `f` to apply a filter
3. Choose filter criteria (schema, object name, or both)
4. Enter filter pattern (supports regex)
5. Press `F` to clear the current filter
6. Press `<leader>fc` to clear all filters

### Filter Levels

- **Object Type Level**: Filter tables, views, procedures, functions independently
- **Structural Group Level**: Filter columns, indexes, keys within an object

### Filter Patterns

Filters support regex patterns:
- `Employee*` - Objects starting with "Employee"
- `*_view` - Objects ending with "_view"
- `^dbo\.` - Objects in dbo schema
- `\d+` - Objects with numbers

### Key Bindings

| Key | Action |
|-----|--------|
| `f` | Apply/edit filter |
| `F` | Clear current filter |
| `<leader>fc` | Clear all filters |
| `<leader>fs` | Show active filters |

### Configuration

```vim
let g:db_ui_filter_key = 'f'
let g:db_ui_filter_case_sensitive = 0
let g:db_ui_filter_use_regex = 1
let g:db_ui_filter_icon = '🔍'
```
```

---

## 8. Future Enhancements (Optional)

1. **Saved filters**: Save common filters for reuse
2. **Filter history**: Recent filters quick access
3. **Multi-column filters**: AND/OR logic for complex queries
4. **Exclude filters**: Show everything EXCEPT pattern
5. **Filter by data type**: Filter columns by int, varchar, etc.
6. **Quick filter shortcuts**: Predefined filters (e.g., "System objects", "User objects")
7. **Filter export**: Save filter configuration to file

---

## 9. Implementation Order Summary

1. ✅ **Phase 1**: Core filter infrastructure (filter.vim)
2. ✅ **Phase 2**: Drawer integration (rendering with filters)
3. ✅ **Phase 3**: User interaction (key bindings, prompts)
4. ✅ **Phase 4**: Configuration (settings, defaults)
5. ✅ **Phase 5**: Regex matching (pattern logic)
6. ⏳ **Phase 6**: Testing (comprehensive test suite)
7. ⏳ **Phase 7**: Documentation (README, help docs)
8. ⏳ **Phase 8**: Polish (icons, error handling, edge cases)

---

## 10. Example Usage Scenarios

### Scenario 1: Finding Employee-related Tables
```
1. Navigate to TABLES group
2. Press 'f'
3. Select 'o' (object filter)
4. Enter: Employee*
5. Result: Only tables with "Employee" in name shown
   - [dbo].[Employees]
   - [dbo].[EmployeeSalaries]
   - [hr].[EmployeeHistory]
```

### Scenario 2: Filter Columns in a Large Table
```
1. Expand [dbo].[Employees] table
2. Navigate to Columns group
3. Press 'f'
4. Enter: *ID
5. Result: Only columns ending with "ID"
   - EmployeeID
   - DepartmentID
   - ManagerID
```

### Scenario 3: Multiple Independent Filters
```
1. Filter TABLES by schema: dbo
   → Shows only dbo tables
2. Navigate to VIEWS
3. Filter VIEWS by object: vw_*
   → Shows only views starting with vw_
4. Both filters active independently
   → TABLES still filtered by dbo
   → VIEWS still filtered by vw_
```

---

## Conclusion

This design provides a comprehensive, elegant filtering system that:
- ✅ Meets all requirements (multi-criteria, independent, real-time, elegant)
- ✅ Integrates seamlessly with existing UI
- ✅ Maintains performance with caching
- ✅ Provides clear visual feedback
- ✅ Follows vim-dadbod-ui patterns and conventions
- ✅ Extensible for future enhancements

The implementation is modular, testable, and maintainable, with clear separation of concerns between filter logic, UI rendering, and user interaction.
