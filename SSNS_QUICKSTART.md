# SSNS Quick Start Guide

## For Your Fresh Claude Code Session

When you start working on SSNS in a new Claude Code instance, use this as your initial prompt:

---

## Initial Prompt

```markdown
I'm building SSNS (SQL Server NeoVim Studio), a complete Lua rewrite of vim-dadbod-ui.

**Context files to read**:
1. SSNS_ARCHITECTURE.md - Class structure (READ THIS FIRST!)
2. SSNS_ROADMAP.md - Development phases
3. INTELLISENSE_IMPLEMENTATION_GUIDE.md - What NOT to do (for later)

**Current Phase**: Phase 1 - Class Hierarchy

**First task**: Implement BaseDbObject in `lua/ssns/classes/base.lua`

**Architecture summary**:
- Hierarchical class structure: Server → Database → Schema → Table → Column
- Single tree for both UI and IntelliSense (later)
- Pure Lua, no VimScript
- Lazy loading with TTL expiration
- Parent/child references for easy navigation

**Key principles**:
1. Every object inherits from BaseDbObject
2. UI state separate from data
3. Factory pattern for object creation
4. Type annotations for LuaLS

Please read SSNS_ARCHITECTURE.md and help me implement the base class with:
- Constructor
- Parent/child management
- get_full_path() method
- is_stale() TTL checking
- Proper LuaLS annotations
```

---

## File Structure to Create

```
ssns/  (new project directory)
├── lua/
│   └── ssns/
│       ├── init.lua
│       ├── config.lua
│       ├── cache.lua
│       ├── factory.lua
│       ├── connection.lua
│       ├── classes/
│       │   ├── base.lua          ← START HERE
│       │   ├── server.lua
│       │   ├── database.lua
│       │   ├── schema.lua
│       │   ├── table.lua
│       │   ├── view.lua
│       │   ├── procedure.lua
│       │   ├── function.lua
│       │   ├── synonym.lua
│       │   ├── column.lua
│       │   ├── index.lua
│       │   ├── constraint.lua
│       │   └── parameter.lua
│       ├── adapters/
│       │   ├── base.lua
│       │   └── sqlserver.lua
│       └── ui/
│           ├── tree.lua
│           ├── buffer.lua
│           ├── query.lua
│           └── highlights.lua
├── doc/
│   └── ssns.txt
├── tests/
│   └── ... (later)
└── README.md
```

---

## First Implementation: BaseDbObject

Start by implementing this in `lua/ssns/classes/base.lua`:

```lua
---@class BaseDbObject
---@field name string Object name
---@field parent BaseDbObject? Parent in hierarchy
---@field children BaseDbObject[] Child objects
---@field is_loaded boolean Has data been fetched?
---@field last_updated number Timestamp of last load
---@field metadata table Extensible metadata
---@field ui_state UiState UI display properties
local BaseDbObject = {}
BaseDbObject.__index = BaseDbObject

---@class UiState
---@field expanded boolean
---@field visible boolean
---@field icon string
---@field highlight_group string
local UiState = {
  expanded = false,
  visible = true,
  icon = "",
  highlight_group = "Normal",
}

---Constructor
---@param opts table
---@return BaseDbObject
function BaseDbObject.new(opts)
  local self = setmetatable({}, BaseDbObject)
  self.name = opts.name or ""
  self.parent = opts.parent
  self.children = {}
  self.is_loaded = false
  self.last_updated = 0
  self.metadata = opts.metadata or {}
  self.ui_state = vim.tbl_deep_extend("force", UiState, opts.ui_state or {})
  return self
end

---Get full hierarchical path
---@return string
function BaseDbObject:get_full_path()
  if not self.parent then
    return self.name
  end
  return self.parent:get_full_path() .. "." .. self.name
end

---Check if object is stale
---@param ttl number Time-to-live in seconds
---@return boolean
function BaseDbObject:is_stale(ttl)
  if not self.is_loaded then
    return true
  end
  local age = os.time() - self.last_updated
  return age > ttl
end

---Refresh object data
---@param force boolean? Force reload even if not stale
function BaseDbObject:refresh(force)
  -- Override in subclasses
  error("refresh() must be implemented by subclass")
end

---Iterator for children
---@return function
function BaseDbObject:get_children()
  local i = 0
  local children = self.children
  return function()
    i = i + 1
    if i <= #children then
      return children[i]
    end
  end
end

---Add child object
---@param child BaseDbObject
function BaseDbObject:add_child(child)
  child.parent = self
  table.insert(self.children, child)
end

---Remove child object
---@param child BaseDbObject
function BaseDbObject:remove_child(child)
  for i, c in ipairs(self.children) do
    if c == child then
      table.remove(self.children, i)
      break
    end
  end
end

---Mark as loaded
function BaseDbObject:mark_loaded()
  self.is_loaded = true
  self.last_updated = os.time()
end

return BaseDbObject
```

---

## Testing Your Base Class

Create `tests/base_spec.lua`:

```lua
local BaseDbObject = require('ssns.classes.base')

describe('BaseDbObject', function()
  it('should create instance', function()
    local obj = BaseDbObject.new({ name = "test" })
    assert.equals("test", obj.name)
    assert.is_false(obj.is_loaded)
  end)

  it('should handle parent/child relationships', function()
    local parent = BaseDbObject.new({ name = "parent" })
    local child = BaseDbObject.new({ name = "child" })
    parent:add_child(child)

    assert.equals(parent, child.parent)
    assert.equals(1, #parent.children)
  end)

  it('should generate full path', function()
    local grandparent = BaseDbObject.new({ name = "server" })
    local parent = BaseDbObject.new({ name = "database" })
    local child = BaseDbObject.new({ name = "table" })

    grandparent:add_child(parent)
    parent:add_child(child)

    assert.equals("server.database.table", child:get_full_path())
  end)

  it('should check staleness', function()
    local obj = BaseDbObject.new({ name = "test" })
    assert.is_true(obj:is_stale(300))  -- Not loaded = stale

    obj:mark_loaded()
    assert.is_false(obj:is_stale(300))  -- Just loaded = fresh
  end)
end)
```

Run with: `nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa!"`

---

## Next Steps After Base Class

1. **ServerClass** - `classes/server.lua`
   - Connection string
   - Connection state management
   - `load_databases()` method

2. **DbClass** - `classes/database.lua`
   - `load_schemas()` method
   - `find_schema()` lookup

3. **Factory** - `factory.lua`
   - `create_server()`
   - `create_database()`

4. **Cache** - `cache.lua`
   - Global servers array
   - Add/remove/find methods

---

## Reference: VimScript to Lua Mapping

When converting from vim-dadbod-ui:

| VimScript | Lua SSNS |
|-----------|----------|
| `s:dbui_instance.dbs` | `cache.servers` |
| `let db.tables = []` | `database.schema_list[i].table_list` |
| `call db#query()` | `adapter:query_tables()` |
| `db.conn` | `server.connection` |
| `db.name` vs `db.db_name` | Just `database.name` (unified!) |
| `b:dbui_db_key_name` | `vim.b.ssns_db_key` |

---

## Common Pitfalls to Avoid

1. ❌ **Don't duplicate data** - One tree, multiple consumers
2. ❌ **Don't mix string/table formats** - Always use objects
3. ❌ **Don't call VimScript from hot paths** - Pure Lua
4. ❌ **Don't forget parent references** - Set in constructor
5. ❌ **Don't eager load everything** - Lazy load columns/indexes

---

## Debugging Tips

```lua
-- Print object hierarchy
function debug_tree(obj, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  print(prefix .. obj.name .. " (" .. obj.__class .. ")")
  for child in obj:get_children() do
    debug_tree(child, indent + 1)
  end
end

-- Check if object loaded
function is_fully_loaded(obj)
  if not obj.is_loaded then
    return false, obj:get_full_path() .. " not loaded"
  end
  for child in obj:get_children() do
    local loaded, reason = is_fully_loaded(child)
    if not loaded then
      return false, reason
    end
  end
  return true
end
```

---

## Integration with vim-dadbod

SSNS will use vim-dadbod for actual SQL execution:

```lua
-- In adapters/sqlserver.lua
local function execute_query(connection, query)
  -- Use vim-dadbod
  local cmd = string.format("db#systemlist('%s', '%s')", connection, query)
  local result = vim.fn.eval(cmd)
  return result
end
```

Keep vim-dadbod for SQL, everything else pure Lua!

---

## Questions to Answer Early

Before implementing ServerClass:

1. **Connection pooling?** Reuse connections or create new each time?
   → **Answer**: Reuse (store in `server.connection`)

2. **Async queries?** Use vim.loop or plenary.async?
   → **Answer**: vim.loop (built-in)

3. **Error handling strategy?** Throw errors or return nil + error msg?
   → **Answer**: Return `success, result_or_error` tuple

4. **TTL default?** 300 seconds reasonable?
   → **Answer**: Yes, configurable in setup()

---

## Success Indicators

You'll know Phase 1 is complete when:

- [ ] All class files created with type annotations
- [ ] Parent/child navigation works
- [ ] Factory can create all object types
- [ ] Cache can store/retrieve servers
- [ ] Tests pass for all classes
- [ ] No errors when requiring modules

---

**Ready to build! Start with `base.lua` and work your way up the hierarchy.** 🚀
