-- ==============================================================================
-- Lualine Component for vim-dadbod-ui
-- ==============================================================================
-- Displays current database connection information in lualine with customizable
-- colors per connection (similar to Redgate's SSMS color-coding feature)
--
-- Usage:
--   require('lualine').setup {
--     sections = {
--       lualine_c = { 'db_ui' }
--     }
--   }
--
-- Configuration (set in VimScript or Lua):
--   vim.g.db_ui_lualine_colors = {
--     ['ProductionDB'] = { fg = '#ffffff', bg = '#ff0000' },  -- Red for production
--     ['DevDB'] = { fg = '#000000', bg = '#00ff00' },         -- Green for dev
--   }
--   vim.g.db_ui_lualine_default_color = { fg = '#ffffff', bg = '#0000ff' }
-- ==============================================================================

local M = {}

-- Load saved colors from JSON file
local function load_colors_from_file()
  -- Get save location
  local save_location = vim.g.db_ui_save_location or '~/.local/share/db_ui'
  -- Expand ~ to home directory
  save_location = vim.fn.expand(save_location)
  local colors_file = save_location .. '/lualine_colors.json'

  -- Check if file exists
  if vim.fn.filereadable(colors_file) == 0 then
    return {}
  end

  -- Read and decode JSON
  local ok, content = pcall(vim.fn.readfile, colors_file)
  if not ok then
    return {}
  end

  local json_str = table.concat(content, '\n')
  ok, saved_colors = pcall(vim.json.decode, json_str)
  if not ok then
    return {}
  end

  return saved_colors
end

-- Load saved colors on first use
local colors_loaded = false
local function ensure_colors_loaded()
  if not colors_loaded then
    -- Load colors from JSON file
    local saved_colors = load_colors_from_file()

    -- Initialize g:db_ui_lualine_colors if not set
    if not vim.g.db_ui_lualine_colors then
      vim.g.db_ui_lualine_colors = {}
    end

    -- Get current colors as a local table
    local current_colors = vim.g.db_ui_lualine_colors or {}

    -- Merge saved colors into local table
    for conn, color in pairs(saved_colors) do
      current_colors[conn] = color
    end

    -- Set the entire table back to vim.g (this is the key fix!)
    vim.g.db_ui_lualine_colors = current_colors

    colors_loaded = true
  end
end

-- Get color configuration for a specific database connection
-- @param db_name: String - Database connection name
-- @return: Table - Color spec { fg = '#rrggbb', bg = '#rrggbb', gui = 'style' }
local function get_connection_color(db_name)
  -- Ensure saved colors are loaded
  ensure_colors_loaded()

  -- Check if color customization is enabled and configured
  local color_map = vim.g.db_ui_lualine_colors or {}
  local default_color = vim.g.db_ui_lualine_default_color or nil

  -- If no color map configured, return nil to use lualine's default
  if vim.tbl_isempty(color_map) and not default_color then
    return nil
  end

  -- Look for exact match first
  if color_map[db_name] then
    return color_map[db_name]
  end

  -- Look for pattern matches (e.g., 'prod*', '*production*')
  for pattern, color in pairs(color_map) do
    -- Convert glob pattern to lua pattern
    local lua_pattern = pattern:gsub('%*', '.*'):gsub('%?', '.')
    if db_name:match(lua_pattern) then
      return color
    end
  end

  -- Return default color or nil
  return default_color
end

-- Extract database name from statusline string
-- @param statusline: String - Full statusline text (e.g., "DBUI: my_blog -> public -> posts")
-- @return: String - Database name only
local function extract_db_name(statusline)
  if not statusline or statusline == '' then
    return nil
  end

  -- Remove prefix if present
  local content = statusline:gsub('^DBUI:%s*', '')

  -- Extract first part (database name) before separator
  local db_name = content:match('^([^-]+)')
  if db_name then
    return vim.trim(db_name)
  end

  return content
end

-- Main component function - returns the statusline text
-- Format: "SERVER | DATABASE (NICKNAME)"
-- @return: String - Formatted database connection info
function M.db_ui()
  -- Check if we're in a database buffer
  local db_key_name = vim.b.dbui_db_key_name
  if not db_key_name or db_key_name == '' then
    return ''
  end

  -- Get buffer variables that contain connection info
  local table_name = vim.b.dbui_table_name or ''
  local schema_name = vim.b.dbui_schema_name or ''
  local db_name = vim.b.dbui_db_name or '' -- The actual database name from DBUI

  -- Get the actual database URL to extract server and database
  local db_url = vim.b.db or ''

  -- Parse the connection URL to get server and database
  -- Format examples:
  -- sqlserver://SERVER/DATABASE
  -- mysql://user:pass@host:port/database
  -- postgresql://user:pass@SERVER:PORT/DATABASE
  local server = ''
  local database = ''

  if db_url ~= '' then
    -- Extract server (after @ if present, otherwise after ://)
    -- This handles: mysql://user:pass@localhost:3306/db
    local server_match = db_url:match('@([^/]+)') -- After @ until /
    if server_match then
      server = server_match
    else
      -- No @ sign, extract after :// until /
      server = db_url:match('://([^/]+)')
    end

    -- Extract database from URL (everything after last / and before ?)
    local url_db = db_url:match('/([^/?]+)$')
    if url_db then
      database = url_db
    end
  end

  -- If we have dbui_db_name (from DBUI context), prefer it over URL database
  -- This handles server-level connections where the database is set via context
  if db_name and db_name ~= '' then
    database = db_name
  end

  -- If still no database, try to extract from USE statement in buffer
  -- This handles server-level connections where database is set via USE statement
  if (not database or database == '' or database == server) then
    -- Get first few lines of buffer to check for USE statement
    local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false)
    for _, line in ipairs(lines) do
      -- Match USE [database] or USE `database` or USE database (case-insensitive)
      local lower_line = line:lower()
      if lower_line:match('^%s*use%s+') then
        local use_db = line:match('^%s*[Uu][Ss][Ee]%s+%[([^%]]+)%]') or
                       line:match('^%s*[Uu][Ss][Ee]%s+`([^`]+)`') or
                       line:match('^%s*[Uu][Ss][Ee]%s+([^;%s]+)')
        if use_db then
          database = use_db
          break
        end
      end
    end
  end

  -- Build the status string
  local parts = {}

  if server and server ~= '' then
    table.insert(parts, server)
  end

  if database and database ~= '' and database ~= server then
    table.insert(parts, database)
  end

  -- Format: "SERVER | DATABASE"
  if #parts > 0 then
    return table.concat(parts, ' | ')
  elseif db_key_name and db_key_name ~= '' then
    -- Fallback if we can't parse URL
    return db_key_name
  end

  return ''
end

-- Color function for the component - returns dynamic color based on connection
-- @return: Table - Color spec or nil for default
function M.db_ui_color()
  -- Check if db_ui#statusline function exists
  if vim.fn.exists('*db_ui#statusline') == 0 then
    return nil
  end

  -- Get full statusline to extract database name
  local statusline = vim.fn['db_ui#statusline']()
  if not statusline or statusline == '' then
    return nil
  end

  -- Extract database name
  local db_name = extract_db_name(statusline)
  if not db_name then
    return nil
  end

  -- Get color for this connection
  return get_connection_color(db_name)
end

-- Lualine component init function
-- This is called by lualine when the component is loaded
function M:init(options)
  -- Store component options
  self.options = vim.tbl_extend('keep', options or {}, {
    icon = '',  -- Database icon (Nerd Font)
  })
end

-- Lualine component update_status function
-- This is called by lualine to get the current status text
function M:update_status()
  return M.db_ui()
end

-- Make the module callable (alternative interface)
setmetatable(M, {
  __call = function()
    return M.db_ui()
  end
})

return M
