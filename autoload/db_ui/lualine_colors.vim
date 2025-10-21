""" ==============================================================================
" Lualine Connection Color Management for vim-dadbod-ui
" ==============================================================================
" Provides interactive color setting and persistence for database connections
" in the lualine statusline component
" ==============================================================================

let s:colors_file = ''

" Initialize colors file path
function! db_ui#lualine_colors#init() abort
  if !empty(g:db_ui_save_location)
    let save_path = substitute(fnamemodify(g:db_ui_save_location, ':p'), '\/$', '', '')
    let s:colors_file = printf('%s/%s', save_path, 'lualine_colors.json')
  endif
endfunction

" Load saved colors from disk
function! db_ui#lualine_colors#load() abort
  call db_ui#lualine_colors#init()

  if empty(s:colors_file) || !filereadable(s:colors_file)
    return {}
  endif

  try
    let content = join(readfile(s:colors_file), "\n")
    return json_decode(content)
  catch
    call db_ui#notifications#error('Failed to load lualine colors: ' . v:exception)
    return {}
  endtry
endfunction

" Save colors to disk
" @param colors: Dict - Color configuration to save
function! db_ui#lualine_colors#save(colors) abort
  call db_ui#lualine_colors#init()

  if empty(s:colors_file)
    call db_ui#notifications#error('Cannot save colors: g:db_ui_save_location is not set')
    return 0
  endif

  " Ensure directory exists
  let save_dir = fnamemodify(s:colors_file, ':h')
  if !isdirectory(save_dir)
    call mkdir(save_dir, 'p')
  endif

  try
    let content = json_encode(a:colors)
    call writefile([content], s:colors_file)
    call db_ui#notifications#info('Lualine colors saved')
    return 1
  catch
    call db_ui#notifications#error('Failed to save lualine colors: ' . v:exception)
    return 0
  endtry
endfunction

" Merge saved colors into global configuration
function! db_ui#lualine_colors#load_and_merge() abort
  let saved_colors = db_ui#lualine_colors#load()

  if !empty(saved_colors)
    " Ensure g:db_ui_lualine_colors is initialized as a proper dict
    if !exists('g:db_ui_lualine_colors') || type(g:db_ui_lualine_colors) != type({})
      let g:db_ui_lualine_colors = {}
    endif

    " Merge saved colors with existing configuration
    " Saved colors take precedence
    for [conn, color] in items(saved_colors)
      let g:db_ui_lualine_colors[conn] = color
    endfor
  endif
endfunction

" Set color for a specific connection
" @param connection_name: String - Database connection name
" @param color_config: Dict - Color specification { fg, bg, gui }
function! db_ui#lualine_colors#set_color(connection_name, color_config) abort
  " Update runtime configuration
  let g:db_ui_lualine_colors[a:connection_name] = a:color_config

  " Load existing saved colors
  let saved_colors = db_ui#lualine_colors#load()

  " Update with new color
  let saved_colors[a:connection_name] = a:color_config

  " Save back to disk
  return db_ui#lualine_colors#save(saved_colors)
endfunction

" Interactive prompt to set connection color
" @param connection_name: String - Database connection name
function! db_ui#lualine_colors#prompt_set_color(connection_name) abort
  " Check if lualine is available
  if !exists('*luaeval') || !luaeval('pcall(require, "lualine")')
    call db_ui#notifications#warning('Lualine is not installed or not available')
    return
  endif

  echo 'Set color for connection: ' . a:connection_name
  echo ''
  echo 'Select a color preset or choose custom:'
  echo '  1. Red (Production)'
  echo '  2. Green (Development)'
  echo '  3. Yellow (Staging)'
  echo '  4. Blue (QA/Testing)'
  echo '  5. Orange (UAT)'
  echo '  6. Purple (Backup/Reporting)'
  echo '  7. Gray (Default)'
  echo '  8. Custom (enter hex codes)'
  echo '  9. Remove color (use lualine default)'
  echo ''

  let choice = input('Enter choice (1-9): ')
  redraw!

  if choice ==# '1'
    let color = { 'fg': '#ffffff', 'bg': '#cc0000', 'gui': 'bold' }
  elseif choice ==# '2'
    let color = { 'fg': '#000000', 'bg': '#00cc00' }
  elseif choice ==# '3'
    let color = { 'fg': '#000000', 'bg': '#cccc00' }
  elseif choice ==# '4'
    let color = { 'fg': '#ffffff', 'bg': '#0066cc' }
  elseif choice ==# '5'
    let color = { 'fg': '#000000', 'bg': '#ff9900' }
  elseif choice ==# '6'
    let color = { 'fg': '#ffffff', 'bg': '#9933cc' }
  elseif choice ==# '7'
    let color = { 'fg': '#ffffff', 'bg': '#666666' }
  elseif choice ==# '8'
    " Custom color entry
    echo ''
    let fg = input('Foreground color (hex, e.g., #ffffff): ')
    if empty(fg) || fg !~# '^#[0-9a-fA-F]\{6\}$'
      call db_ui#notifications#error('Invalid foreground color. Must be hex format like #ffffff')
      return
    endif

    let bg = input('Background color (hex, e.g., #ff0000): ')
    if empty(bg) || bg !~# '^#[0-9a-fA-F]\{6\}$'
      call db_ui#notifications#error('Invalid background color. Must be hex format like #ff0000')
      return
    endif

    let gui = input('Text style (bold/italic/underline, or leave empty): ')

    let color = { 'fg': fg, 'bg': bg }
    if !empty(gui)
      let color.gui = gui
    endif
    redraw!
  elseif choice ==# '9'
    " Remove color
    call db_ui#lualine_colors#remove_color(a:connection_name)
    return
  else
    call db_ui#notifications#warning('Invalid choice')
    return
  endif

  " Save the color
  if db_ui#lualine_colors#set_color(a:connection_name, color)
    call db_ui#notifications#info('Color set for ' . a:connection_name . ': ' . string(color))

    " Check if lualine has db_ui component configured
    if exists('*luaeval')
      let has_component = luaeval('require("lualine").get_config().sections.lualine_c ~= nil')
      if !has_component
        echo ''
        echo 'Note: To see connection colors in your statusline, add db_ui to lualine config:'
        echo "  require('lualine').setup { sections = { lualine_c = { 'db_ui' } } }"
        echo ''
      endif
    endif

    " Refresh lualine if available
    if exists(':LualineRefresh') == 2
      LualineRefresh
    endif
  endif
endfunction

" Remove color for a connection
" @param connection_name: String - Database connection name
function! db_ui#lualine_colors#remove_color(connection_name) abort
  " Remove from runtime configuration
  if has_key(g:db_ui_lualine_colors, a:connection_name)
    call remove(g:db_ui_lualine_colors, a:connection_name)
  endif

  " Load saved colors
  let saved_colors = db_ui#lualine_colors#load()

  " Remove from saved colors
  if has_key(saved_colors, a:connection_name)
    call remove(saved_colors, a:connection_name)
    call db_ui#lualine_colors#save(saved_colors)
    call db_ui#notifications#info('Color removed for ' . a:connection_name)
  else
    call db_ui#notifications#info('No saved color for ' . a:connection_name)
  endif

  " Refresh lualine if available
  if exists(':LualineRefresh') == 2
    LualineRefresh
  endif
endfunction

" List all saved connection colors
function! db_ui#lualine_colors#list() abort
  let saved_colors = db_ui#lualine_colors#load()

  if empty(saved_colors)
    call db_ui#notifications#info('No saved connection colors')
    return
  endif

  echo 'Saved connection colors:'
  echo ''
  for [conn, color] in items(saved_colors)
    echo '  ' . conn . ': ' . string(color)
  endfor
endfunction
