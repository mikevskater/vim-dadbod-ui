-- ==============================================================================
-- Example Lualine Configuration for vim-dadbod-ui
-- ==============================================================================
-- This example shows how to integrate vim-dadbod-ui's database connection
-- information into your lualine statusline with color-coded connections.
--
-- Copy relevant sections to your Neovim configuration (init.lua)
-- ==============================================================================

-- ==============================================================================
-- INTERACTIVE COLOR SETTING (Recommended)
-- ==============================================================================
-- You can set colors interactively from the DBUI drawer!
-- 1. Open DBUI drawer with :DBUI
-- 2. Navigate to any database connection
-- 3. Press '<Leader>c' to set the connection color (typically '\c' by default)
-- 4. Choose from presets or create custom colors
-- 5. Colors are saved automatically to ~/.local/share/db_ui/lualine_colors.json
--
-- Available commands:
--   :DBUISetLualineColor ConnectionName     - Set color for a connection
--   :DBUIRemoveLualineColor ConnectionName  - Remove color for a connection
--   :DBUIListLualineColors                  - List all saved colors
--
-- ==============================================================================
-- MANUAL COLOR CONFIGURATION (Optional)
-- ==============================================================================
-- Configure connection colors BEFORE setting up lualine
-- These colors help visually distinguish between different database environments
-- Note: Interactively set colors will override these settings
vim.g.db_ui_lualine_colors = {
  -- Production databases - RED (danger!)
  ['ProductionDB'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*prod*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*production*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*live*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },

  -- Development databases - GREEN (safe)
  ['DevDB'] = { fg = '#000000', bg = '#00cc00' },
  ['*dev*'] = { fg = '#000000', bg = '#00cc00' },
  ['*development*'] = { fg = '#000000', bg = '#00cc00' },
  ['localhost'] = { fg = '#000000', bg = '#00cc00' },
  ['127.0.0.1'] = { fg = '#000000', bg = '#00cc00' },

  -- Staging databases - YELLOW (caution)
  ['StagingDB'] = { fg = '#000000', bg = '#cccc00' },
  ['*staging*'] = { fg = '#000000', bg = '#cccc00' },
  ['*uat*'] = { fg = '#000000', bg = '#cccc00' },
  ['*test*'] = { fg = '#000000', bg = '#cccc00' },

  -- QA databases - ORANGE
  ['*qa*'] = { fg = '#000000', bg = '#ff9900' },

  -- Backup/Reporting databases - BLUE
  ['*backup*'] = { fg = '#ffffff', bg = '#0066cc' },
  ['*reporting*'] = { fg = '#ffffff', bg = '#0066cc' },
}

-- Default color for any connection not matching above patterns
vim.g.db_ui_lualine_default_color = { fg = '#ffffff', bg = '#666666' }

-- ==============================================================================
-- Lualine Setup
-- ==============================================================================

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},

    -- Add db_ui component to section C (center-left)
    lualine_c = {
      'filename',
      'db_ui',  -- Simple usage - uses global color configuration
    },

    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}

-- ==============================================================================
-- Advanced Configuration Examples
-- ==============================================================================

-- Example 1: Custom icon and explicit color function
--[[
require('lualine').setup {
  sections = {
    lualine_c = {
      {
        'db_ui',
        icon = '󰆼',  -- Database icon (requires Nerd Fonts)
        color = function()
          -- Custom color logic
          local db_name = vim.fn['db_ui#statusline']()
          if db_name and db_name:match('prod') then
            return { fg = '#ffffff', bg = '#ff0000', gui = 'bold' }
          end
          return { fg = '#ffffff', bg = '#0066cc' }
        end,
      }
    }
  }
}
]]

-- Example 2: Multiple sections with db_ui
--[[
require('lualine').setup {
  sections = {
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = {
      'filename',
      {
        'db_ui',
        icon = '',
        -- Separator to distinguish from filename
        separator = { left = '', right = '' },
      }
    },
  }
}
]]

-- Example 3: Conditional display (only show when connected to database)
--[[
require('lualine').setup {
  sections = {
    lualine_c = {
      'filename',
      {
        function()
          local component = require('lualine.components.db_ui')
          local status = component.db_ui()
          return status ~= '' and status or nil
        end,
        icon = '󰆼',
        color = function()
          local component = require('lualine.components.db_ui')
          return component.db_ui_color()
        end,
      }
    }
  }
}
]]

-- ==============================================================================
-- Tips
-- ==============================================================================

-- 1. Use pattern matching for flexible connection matching:
--    '*prod*'        - Matches any connection containing 'prod'
--    'prod*'         - Matches connections starting with 'prod'
--    '*_production'  - Matches connections ending with '_production'
--
-- 2. Order matters! More specific patterns should come before general ones:
--    ['ProductionDB'] = { ... }  -- Specific match first
--    ['*prod*'] = { ... }        -- General pattern second
--
-- 3. Test your colors with different terminal backgrounds:
--    - Dark backgrounds: Use lighter foregrounds
--    - Light backgrounds: Use darker foregrounds
--
-- 4. Consider accessibility:
--    - Use high contrast colors
--    - Don't rely solely on color (use 'bold' for important connections)
--    - Test with colorblindness simulators
--
-- 5. Environment-based configuration:
--    Set different color schemes based on your work environment
--    (e.g., stricter colors when working from office vs. home)
