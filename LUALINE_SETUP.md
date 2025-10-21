# Lualine Integration Quick Start

## Step 1: Add db_ui Component to Lualine

To see database connection info and colors in your statusline, you need to add the `db_ui` component to your lualine configuration.

### Option A: Minimal Setup (Lua)

Add this to your `init.lua` or lualine config file:

```lua
require('lualine').setup {
  sections = {
    lualine_c = { 'db_ui' }  -- Add db_ui component
  }
}
```

### Option B: Keep Existing Components (Lua)

If you already have lualine configured, just add `'db_ui'` to your existing `lualine_c` section:

```lua
require('lualine').setup {
  sections = {
    lualine_c = {
      'filename',
      'db_ui',  -- Add this line
    }
  }
}
```

### Option C: VimScript Configuration

If using VimScript (`init.vim`):

```vim
lua << EOF
require('lualine').setup {
  sections = {
    lualine_c = { 'filename', 'db_ui' }
  }
}
EOF
```

## Step 2: Verify It's Working

1. Restart Neovim (or reload your config with `:source %`)
2. Open DBUI: `:DBUI`
3. Open a query buffer from any table
4. Check your statusline - you should see: `DatabaseName → schema → table`

## Step 3: Set Connection Colors

1. In DBUI drawer, navigate to a database connection
2. Press `<Leader>c` (typically `\c`)
3. Choose a color preset (e.g., 1 for Red/Production, 2 for Green/Development)
4. Open a query buffer
5. Your statusline background should now show the selected color!

## Troubleshooting

### "I don't see database info in my statusline"

**Check 1:** Is `db_ui` in your lualine config?
```lua
-- Run this in Neovim command mode:
:lua print(vim.inspect(require('lualine').get_config().sections.lualine_c))
```

You should see `'db_ui'` in the output.

**Check 2:** Did you reload your config?
```vim
:source $MYVIMRC
```

**Check 3:** Are you in a database query buffer?

The component only shows when you're in a SQL query buffer opened from DBUI.

### "Colors are saved but not showing"

**Check 1:** Did you add the component to lualine? (See Step 1)

**Check 2:** Is the color set for the right connection?
```vim
:DBUIListLualineColors
```

**Check 3:** Try refreshing lualine:
```vim
:LualineRefresh
```

### "I see the database name but no color"

The connection name in the saved colors must match the database name shown in the statusline.

Example:
- Statusline shows: `my_database → public → users`
- Color should be set for: `my_database`

Run `:DBUIListLualineColors` to verify.

## Full Example Configuration

Here's a complete example with common settings:

```lua
-- In your init.lua or lualine config

-- Set connection colors (optional - can also use interactive \c command)
vim.g.db_ui_lualine_colors = {
  ['*prod*'] = { fg = '#ffffff', bg = '#cc0000', gui = 'bold' },
  ['*dev*'] = { fg = '#000000', bg = '#00cc00' },
}

-- Configure lualine
require('lualine').setup {
  options = {
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = {
      'filename',
      'db_ui',  -- Database connection info with colors
    },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' }
  },
}
```

## Need More Help?

See the full documentation in the README.md file, section "Lualine Integration".
