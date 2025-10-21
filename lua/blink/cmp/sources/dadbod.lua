---@class blink.cmp.Source
local source = {}

-- LSP CompletionItemKind mapping for database objects
local CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25,
}

-- Map database object kinds to LSP CompletionItemKind
local kind_map = {
  C = CompletionItemKind.Field,      -- Column
  T = CompletionItemKind.Class,      -- Table
  V = CompletionItemKind.Class,      -- View
  P = CompletionItemKind.Method,     -- Procedure
  F = CompletionItemKind.Function,   -- Function
  D = CompletionItemKind.Module,     -- Database
  S = CompletionItemKind.Folder,     -- Schema
  A = CompletionItemKind.Variable,   -- Alias
  R = CompletionItemKind.Keyword,    -- Reserved keyword
  param = CompletionItemKind.Variable, -- Parameter
}

---Create a new instance of the source
---@return blink.cmp.Source
function source.new()
  local self = setmetatable({}, { __index = source })
  self.cache = {}
  return self
end

---Get trigger characters for completion
---@return string[]
function source:get_trigger_characters()
  return { '.', '"', '`', '[', ']', '@' }
end

---Check if source is enabled for current buffer
---@return boolean
function source:enabled()
  local filetype = vim.bo.filetype
  local supported_filetypes = { 'sql', 'mysql', 'plsql', 'dbout', 'dbui' }

  -- Check if filetype is supported
  if not vim.tbl_contains(supported_filetypes, filetype) then
    return false
  end

  -- Check if IntelliSense is enabled
  if vim.g.db_ui_enable_intellisense == 0 then
    return false
  end

  -- Check if IntelliSense is available
  return vim.fn.exists('*db_ui#completion#is_available') == 1 and
         vim.fn['db_ui#completion#is_available']() == 1
end

---Get completions for the current context
---@param ctx blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
---@return fun(): nil # Cancellation function
function source:get_completions(ctx, callback)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get database key name from buffer
  local db_key_name = vim.b[bufnr].dbui_db_key_name
  if not db_key_name or db_key_name == '' then
    callback({ context = ctx, is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return function() end
  end

  -- Get current line and cursor position
  local line = ctx.line
  local col = ctx.cursor[2]

  -- Get cursor context using Phase 2 parser
  local context = vim.fn['db_ui#completion#get_cursor_context'](bufnr, line, col)

  -- Calculate base text for filtering
  local word_start = col + 1
  local triggers = self:get_trigger_characters()
  while word_start > 1 do
    local char = line:sub(word_start - 1, word_start - 1)
    if vim.tbl_contains(triggers, char) or char:match('%s') then
      break
    end
    word_start = word_start - 1
  end

  local base = line:sub(word_start, col)
  if base ~= '' and base:match('[^0-9A-Za-z_@]+') then
    base = ''
  end

  -- Get completions based on context type
  local items = self:get_items_for_context(db_key_name, context, base)

  -- Transform to blink.cmp format
  local completion_items = {}
  for _, item in ipairs(items) do
    table.insert(completion_items, self:transform_item(item))
  end

  callback({
    context = ctx,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = completion_items,
  })

  return function() end -- No-op cancellation
end

---Get completion items based on context type
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_items_for_context(db_key_name, context, base)
  local context_type = context.type or 'all_objects'

  if context_type == 'column' then
    return self:get_column_items(db_key_name, context, base)
  elseif context_type == 'table' then
    return self:get_table_items(db_key_name, context, base)
  elseif context_type == 'schema' then
    return self:get_schema_items(db_key_name, context, base)
  elseif context_type == 'database' then
    return self:get_database_items(db_key_name, context, base)
  elseif context_type == 'procedure' then
    return self:get_procedure_items(db_key_name, context, base)
  elseif context_type == 'function' then
    return self:get_function_items(db_key_name, context, base)
  elseif context_type == 'parameter' then
    return self:get_parameter_items(db_key_name, context, base)
  elseif context_type == 'column_or_function' then
    local items = {}
    vim.list_extend(items, self:get_column_items(db_key_name, context, base))
    vim.list_extend(items, self:get_function_items(db_key_name, context, base))
    return items
  elseif context_type == 'all_objects' then
    return self:get_all_object_items(db_key_name, context, base)
  else
    return {}
  end
end

---Get column completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_column_items(db_key_name, context, base)
  local table_name = ''
  local external_db = nil

  -- Resolve table name from alias or direct reference
  if context.alias and context.alias ~= '' then
    if context.aliases[context.alias] then
      local alias_info = context.aliases[context.alias]
      table_name = alias_info.table
      external_db = alias_info.database ~= '' and alias_info.database or nil
    end
  elseif context.table and context.table ~= '' then
    table_name = context.table
    external_db = context.database ~= '' and context.database or nil
  end

  if table_name == '' then
    return {}
  end

  -- Get columns from cache
  local raw_columns
  if external_db then
    -- External database columns (future enhancement)
    raw_columns = {}
  else
    raw_columns = vim.fn['db_ui#completion#get_completions'](db_key_name, 'columns', table_name)
  end

  -- Format items
  local items = {}
  for _, col in ipairs(raw_columns) do
    local item = {
      word = col.name,
      kind = 'C',
      data_type = col.data_type,
      nullable = col.nullable,
      is_pk = col.is_pk,
      is_fk = col.is_fk,
      info = self:format_column_info(col),
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get table completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_table_items(db_key_name, context, base)
  local raw_objects

  if context.database and context.database ~= '' then
    -- External database tables
    raw_objects = vim.fn['db_ui#completion#get_external_completions'](
      db_key_name,
      context.database,
      'all_objects',
      base
    )
  else
    -- Current database tables and views
    local tables = vim.fn['db_ui#completion#get_completions'](db_key_name, 'tables')
    local views = vim.fn['db_ui#completion#get_completions'](db_key_name, 'views')
    raw_objects = vim.list_extend(tables, views)
  end

  -- Format items
  local items = {}
  for _, obj in ipairs(raw_objects) do
    local item = {
      word = obj.name,
      kind = obj.type == 'view' and 'V' or 'T',
      object_type = obj.type,
      schema = obj.schema,
      database = obj.database,
      info = self:format_table_info(obj),
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get schema completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_schema_items(db_key_name, context, base)
  local raw_schemas = vim.fn['db_ui#completion#get_completions'](db_key_name, 'schemas')

  local items = {}
  for _, schema in ipairs(raw_schemas) do
    local schema_name = type(schema) == 'string' and schema or schema.name
    local item = {
      word = schema_name,
      kind = 'S',
      info = 'Schema',
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get database completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_database_items(db_key_name, context, base)
  local raw_databases = vim.fn['db_ui#completion#get_completions'](db_key_name, 'databases')

  local items = {}
  for _, db in ipairs(raw_databases) do
    local db_name = type(db) == 'string' and db or db.name
    local item = {
      word = db_name,
      kind = 'D',
      info = 'Database',
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get procedure completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_procedure_items(db_key_name, context, base)
  local raw_procedures = vim.fn['db_ui#completion#get_completions'](db_key_name, 'procedures')

  local items = {}
  for _, proc in ipairs(raw_procedures) do
    local proc_name = type(proc) == 'string' and proc or proc.name
    local item = {
      word = proc_name,
      kind = 'P',
      info = 'Stored Procedure',
      signature = self:get_procedure_signature(db_key_name, proc_name),
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get function completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_function_items(db_key_name, context, base)
  local raw_functions = vim.fn['db_ui#completion#get_completions'](db_key_name, 'functions')

  local items = {}
  for _, func in ipairs(raw_functions) do
    local func_name = type(func) == 'string' and func or func.name
    local item = {
      word = func_name,
      kind = 'F',
      info = 'Function',
      signature = self:get_function_signature(db_key_name, func_name),
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get parameter completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_parameter_items(db_key_name, context, base)
  local items = {}

  -- Check for bind parameters
  local bufnr = vim.api.nvim_get_current_buf()
  local bind_params = vim.b[bufnr].dbui_bind_params or {}

  for param_name, param_val in pairs(bind_params) do
    local item = {
      word = param_name:sub(2), -- Remove leading @
      kind = 'param',
      info = tostring(param_val),
    }
    table.insert(items, item)
  end

  -- Filter by base
  if base ~= '' then
    items = vim.tbl_filter(function(item)
      return item.word:lower():find('^' .. base:lower(), 1, true) ~= nil
    end, items)
  end

  return items
end

---Get all object completion items
---@param db_key_name string
---@param context table
---@param base string
---@return table[]
function source:get_all_object_items(db_key_name, context, base)
  local items = {}
  vim.list_extend(items, self:get_table_items(db_key_name, context, base))
  vim.list_extend(items, self:get_procedure_items(db_key_name, context, base))
  vim.list_extend(items, self:get_function_items(db_key_name, context, base))
  return items
end

---Transform item to blink.cmp format
---@param item table
---@return lsp.CompletionItem
function source:transform_item(item)
  local completion_item = {
    label = item.word,
    kind = kind_map[item.kind] or CompletionItemKind.Text,
    insertText = item.word,
    filterText = item.word,
    sortText = item.word,
  }

  -- Add data type to label details
  if item.data_type and item.data_type ~= '' then
    completion_item.labelDetails = {
      detail = ' ' .. item.data_type,
      description = item.info,
    }
  end

  -- Add documentation
  if item.info and item.info ~= '' then
    completion_item.documentation = {
      kind = 'markdown',
      value = item.info,
    }
  end

  -- Add signature for procedures/functions
  if item.signature and item.signature ~= '' then
    local doc_text = item.info or ''
    if doc_text ~= '' then
      doc_text = doc_text .. '\n\n'
    end
    doc_text = doc_text .. '**Signature:**\n```sql\n' .. item.signature .. '\n```'
    completion_item.documentation = {
      kind = 'markdown',
      value = doc_text,
    }
  end

  return completion_item
end

---Format column information
---@param column table
---@return string
function source:format_column_info(column)
  local info = {}

  if column.data_type and column.data_type ~= '' then
    table.insert(info, '**Type:** `' .. column.data_type .. '`')
  end

  if column.nullable ~= nil then
    table.insert(info, column.nullable and '`NULL`' or '`NOT NULL`')
  end

  if column.is_pk then
    table.insert(info, '🔑 **PRIMARY KEY**')
  end

  if column.is_fk then
    table.insert(info, '🔗 **FOREIGN KEY**')
  end

  return table.concat(info, ' | ')
end

---Format table information
---@param tbl table
---@return string
function source:format_table_info(tbl)
  local info = {}

  local obj_type = tbl.type or 'table'
  table.insert(info, '**Type:** `' .. obj_type:upper() .. '`')

  if tbl.schema and tbl.schema ~= '' then
    table.insert(info, '**Schema:** `' .. tbl.schema .. '`')
  end

  if tbl.database and tbl.database ~= '' then
    table.insert(info, '**Database:** `' .. tbl.database .. '`')
  end

  return table.concat(info, ' | ')
end

---Get procedure signature
---@param db_key_name string
---@param proc_name string
---@return string
function source:get_procedure_signature(db_key_name, proc_name)
  -- Try to get parameters from cache
  local params = vim.fn['db_ui#completion#get_completions'](db_key_name, 'parameters', proc_name)

  if params and #params > 0 then
    local param_strs = {}
    for _, param in ipairs(params) do
      local param_str = param.name
      if param.data_type and param.data_type ~= '' then
        param_str = param_str .. ' ' .. param.data_type
      end
      table.insert(param_strs, param_str)
    end
    return proc_name .. '(' .. table.concat(param_strs, ', ') .. ')'
  end

  return proc_name .. '(...)'
end

---Get function signature
---@param db_key_name string
---@param func_name string
---@return string
function source:get_function_signature(db_key_name, func_name)
  -- Try to get parameters from cache
  local params = vim.fn['db_ui#completion#get_completions'](db_key_name, 'parameters', func_name)

  if params and #params > 0 then
    local param_strs = {}
    for _, param in ipairs(params) do
      local param_str = param.name
      if param.data_type and param.data_type ~= '' then
        param_str = param_str .. ' ' .. param.data_type
      end
      table.insert(param_strs, param_str)
    end
    return func_name .. '(' .. table.concat(param_strs, ', ') .. ')'
  end

  return func_name .. '(...)'
end

return source
