let s:drawer_instance = {}
let s:drawer = {}

function db_ui#drawer#new(dbui)
  let s:drawer_instance = s:drawer.new(a:dbui)
  return s:drawer_instance
endfunction
function db_ui#drawer#get()
  return s:drawer_instance
endfunction

function! s:drawer.new(dbui) abort
  let instance = copy(self)
  let instance.dbui = a:dbui
  let instance.show_details = 0
  let instance.show_help = 0
  let instance.show_dbout_list = 0
  let instance.content = []
  let instance.query = {}
  let instance.connections = {}

  return instance
endfunction

function! s:drawer.open(...) abort
  if self.is_opened()
    silent! exe self.get_winnr().'wincmd w'
    return
  endif
  let mods = get(a:, 1, '')
  if !empty(mods)
    silent! exe mods.' new dbui'
  else
    let win_pos = g:db_ui_win_position ==? 'left' ? 'topleft' : 'botright'
    silent! exe 'vertical '.win_pos.' new dbui'
    silent! exe 'vertical '.win_pos.' resize '.g:db_ui_winwidth
  endif
  setlocal filetype=dbui buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell nomodifiable winfixwidth nonumber norelativenumber signcolumn=no

  call self.render()
  nnoremap <silent><buffer> <Plug>(DBUI_SelectLine) :call <sid>method('toggle_line', 'edit')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_DeleteLine) :call <sid>method('delete_line')<CR>
  let query_win_pos = g:db_ui_win_position ==? 'left' ? 'botright' : 'topleft'
  silent! exe "nnoremap <silent><buffer> <Plug>(DBUI_SelectLineVsplit) :call <sid>method('toggle_line', 'vertical ".query_win_pos." split')<CR>"
  nnoremap <silent><buffer> <Plug>(DBUI_Redraw) :call <sid>method('redraw')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_AddConnection) :call <sid>method('add_connection')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_ToggleDetails) :call <sid>method('toggle_details')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_RenameLine) :call <sid>method('rename_line')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_Quit) :call <sid>method('quit')<CR>

  nnoremap <silent><buffer> <Plug>(DBUI_GotoFirstSibling) :call <sid>method('goto_sibling', 'first')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_GotoNextSibling) :call <sid>method('goto_sibling', 'next')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_GotoPrevSibling) :call <sid>method('goto_sibling', 'prev')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_GotoLastSibling) :call <sid>method('goto_sibling', 'last')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_GotoParentNode) :call <sid>method('goto_node', 'parent')<CR>
  nnoremap <silent><buffer> <Plug>(DBUI_GotoChildNode) :call <sid>method('goto_node', 'child')<CR>

  nnoremap <silent><buffer> ? :call <sid>method('toggle_help')<CR>
  augroup db_ui
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call s:method('render')
  augroup END
  silent! doautocmd User DBUIOpened
endfunction

function! s:drawer.is_opened() abort
  return self.get_winnr() > -1
endfunction

function! s:drawer.get_winnr() abort
  for nr in range(1, winnr('$'))
    if getwinvar(nr, '&filetype') ==? 'dbui'
      return nr
    endif
  endfor
  return -1
endfunction

function! s:drawer.redraw() abort
  let item = self.get_current_item()
  if item.level ==? 0
    return self.render({ 'dbs': 1, 'queries': 1 })
  endif
  return self.render({'db_key_name': item.dbui_db_key_name, 'queries': 1 })
endfunction

function! s:drawer.toggle() abort
  if self.is_opened()
    return self.quit()
  endif
  return self.open()
endfunction

function! s:drawer.quit() abort
  if self.is_opened()
    silent! exe 'bd'.winbufnr(self.get_winnr())
  endif
endfunction

function! s:method(method_name, ...) abort
  if a:0 > 0
    return s:drawer_instance[a:method_name](a:1)
  endif

  return s:drawer_instance[a:method_name]()
endfunction

function! s:drawer.goto_sibling(direction)
  let index = line('.') - 1
  let last_index = len(self.content) - 1
  let item = self.content[index]
  let current_level = item.level
  let is_up = a:direction ==? 'first' || a:direction ==? 'prev'
  let is_down = !is_up
  let is_edge = a:direction ==? 'first' || a:direction ==? 'last'
  let is_prev_or_next = !is_edge
  let last_index_same_level = index

  while ((is_up && index >= 0) || (is_down && index < last_index))
    let adjacent_index = is_up ? index - 1 : index + 1
    let is_on_edge = (is_up && adjacent_index ==? 0) || (is_down && adjacent_index ==? last_index)
    let adjacent_item = self.content[adjacent_index]
    if adjacent_item.level ==? 0 && adjacent_item.label ==? ''
      return cursor(index + 1, col('.'))
    endif

    if is_prev_or_next
      if adjacent_item.level ==? current_level
        return cursor(adjacent_index + 1, col('.'))
      endif
      if adjacent_item.level < current_level
        return
      endif
    endif

    if is_edge
      if adjacent_item.level ==? current_level
        let last_index_same_level = adjacent_index
      endif
      if adjacent_item.level < current_level || is_on_edge
        return cursor(last_index_same_level + 1, col('.'))
      endif
    endif
    let index = adjacent_index
  endwhile
endfunction

function! s:drawer.goto_node(direction)
  let index = line('.') - 1
  let item = self.content[index]
  let last_index = len(self.content) - 1
  let is_up = a:direction ==? 'parent'
  let is_down = !is_up
  let Is_correct_level = {adj-> a:direction ==? 'parent' ? adj.level ==? item.level - 1 : adj.level ==? item.level + 1}
  if is_up
    while index >= 0
      let index = index - 1
      let adjacent_item = self.content[index]
      if adjacent_item.level < item.level
        break
      endif
    endwhile
    return cursor(index + 1, col('.'))
  endif

  if item.action !=? 'toggle'
    return
  endif

  if !item.expanded
    call self.toggle_line('')
  endif
  norm! j
endfunction

function s:drawer.get_current_item() abort
  return self.content[line('.') - 1]
endfunction

function! s:drawer.rename_buffer(buffer, db_key_name, is_saved_query) abort
  let bufnr = bufnr(a:buffer)
  let current_win = winnr()
  let current_ft = &filetype

  if !filereadable(a:buffer)
    return db_ui#notifications#error('Only written queries can be renamed.')
  endif

  if empty(a:db_key_name)
    return db_ui#notifications#error('Buffer not attached to any database')
  endif

  let bufwin = bufwinnr(bufnr)
  let db = self.dbui.dbs[a:db_key_name]
  let db_slug = db_ui#utils#slug(db.name)
  let is_saved = a:is_saved_query || !self.dbui.is_tmp_location_buffer(db, a:buffer)
  let old_name = self.get_buffer_name(db, a:buffer)

  try
    let new_name = db_ui#utils#input('Enter new name: ', old_name)
  catch /.*/
    return db_ui#notifications#error(v:exception)
  endtry

  if empty(new_name)
    return db_ui#notifications#error('Valid name must be provided.')
  endif

  if is_saved
    let new = printf('%s/%s', fnamemodify(a:buffer, ':p:h'), new_name)
  else
    let new = printf('%s/%s', fnamemodify(a:buffer, ':p:h'), db_slug.'-'.new_name)
    call add(db.buffers.tmp, new)
  endif

  call rename(a:buffer, new)
  let new_bufnr = -1

  if bufwin > -1
    call self.get_query().open_buffer(db, new, 'edit')
    let new_bufnr = bufnr('%')
  elseif bufnr > -1
    exe 'badd '.new
    let new_bufnr = bufnr(new)
    call add(db.buffers.list, new)
  elseif index(db.buffers.list, a:buffer) > -1
    call insert(db.buffers.list, new, index(db.buffers.list, a:buffer))
  endif

  call filter(db.buffers.list, 'v:val !=? a:buffer')

  if new_bufnr > - 1
    call setbufvar(new_bufnr, 'dbui_db_key_name', db.key_name)
    call setbufvar(new_bufnr, 'db', db.conn)
    call setbufvar(new_bufnr, 'dbui_db_table_name', getbufvar(a:buffer, 'dbui_db_table_name'))
    call setbufvar(new_bufnr, 'dbui_bind_params', getbufvar(a:buffer, 'dbui_bind_params'))
  endif

  silent! exe 'bw! '.a:buffer
  if winnr() !=? current_win
    wincmd p
  endif

  return self.render({ 'queries': 1 })
endfunction

function! s:drawer.rename_line() abort
  let item = self.get_current_item()
  if item.type ==? 'buffer'
    return self.rename_buffer(item.file_path, item.dbui_db_key_name, get(item, 'saved', 0))
  endif

  if item.type ==? 'db' || item.type ==? 'server'
    return self.get_connections().rename(self.dbui.dbs[item.dbui_db_key_name])
  endif

  return
endfunction

function! s:drawer.add_connection() abort
  return self.get_connections().add()
endfunction

function! s:drawer.toggle_dbout_queries() abort
  let self.show_dbout_list = !self.show_dbout_list
  return self.render()
endfunction

function! s:drawer.delete_connection(db) abort
  return self.get_connections().delete(a:db)
endfunction

function! s:drawer.get_connections() abort
  if empty(self.connections)
    let self.connections = db_ui#connections#new(self)
  endif

  return self.connections
endfunction

function! s:drawer.toggle_help() abort
  let self.show_help = !self.show_help
  return self.render()
endfunction

function! s:drawer.toggle_details() abort
  let self.show_details = !self.show_details
  return self.render()
endfunction

function! s:drawer.focus() abort
  if &filetype ==? 'dbui'
    return 0
  endif

  let winnr = self.get_winnr()
  if winnr > -1
    exe winnr.'wincmd w'
    return 1
  endif
  return 0
endfunction

function! s:drawer.render(...) abort
  let opts = get(a:, 1, {})
  let restore_win = self.focus()

  if &filetype !=? 'dbui'
    return
  endif

  if get(opts, 'dbs', 0)
    let query_time = reltime()
    call db_ui#notifications#info('Refreshing all databases...')
    call self.dbui.populate_dbs()
    call db_ui#notifications#info('Refreshed all databases after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  endif

  if !empty(get(opts, 'db_key_name', ''))
    let db = self.dbui.dbs[opts.db_key_name]
    call db_ui#notifications#info('Refreshing database '.db.name.'...')
    let query_time = reltime()
    let self.dbui.dbs[opts.db_key_name] = self.populate(db)
    call db_ui#notifications#info('Refreshed database '.db.name.' after '.split(reltimestr(reltime(query_time)))[0].' sec.')
  endif

  redraw!
  let view = winsaveview()
  let self.content = []

  call self.render_help()

  for db in self.dbui.dbs_list
    if get(opts, 'queries', 0)
      call self.load_saved_queries(self.dbui.dbs[db.key_name])
    endif
    call self.add_db(self.dbui.dbs[db.key_name])
  endfor

  if empty(self.dbui.dbs_list)
    call self.add('" No connections', 'noaction', 'help', '', '', 0)
    call self.add('Add connection', 'call_method', 'add_connection', g:db_ui_icons.add_connection, '', 0)
  endif


  if !empty(self.dbui.dbout_list)
    call self.add('', 'noaction', 'help', '', '', 0)
    call self.add('Query results ('.len(self.dbui.dbout_list).')', 'call_method', 'toggle_dbout_queries', self.get_toggle_icon('saved_queries', {'expanded': self.show_dbout_list}), '', 0)

    if self.show_dbout_list
      let entries = sort(keys(self.dbui.dbout_list), function('s:sort_dbout'))
      for entry in entries
        let content = ''
        if !empty(self.dbui.dbout_list[entry])
          let content = printf(' (%s)', self.dbui.dbout_list[entry].content)
        endif
        call self.add(fnamemodify(entry, ':t').content, 'open', 'dbout', g:db_ui_icons.tables, '', 1, { 'file_path': entry })
      endfor
    endif
  endif

  let content = map(copy(self.content), 'repeat(" ", shiftwidth() * v:val.level).v:val.icon.(!empty(v:val.icon) ? " " : "").v:val.label')

  setlocal modifiable
  silent 1,$delete _
  call setline(1, content)
  setlocal nomodifiable
  call winrestview(view)

  if restore_win
    wincmd p
  endif
endfunction

function! s:drawer.render_help() abort
  if g:db_ui_show_help
    call self.add('" Press ? for help', 'noaction', 'help', '', '', 0)
    call self.add('', 'noaction', 'help', '', '', 0)
  endif

  if self.show_help
    call self.add('" o - Open/Toggle selected item', 'noaction', 'help', '', '', 0)
    call self.add('" S - Open/Toggle selected item in vertical split', 'noaction', 'help', '', '', 0)
    call self.add('" d - Delete selected item', 'noaction', 'help', '', '', 0)
    call self.add('" R - Redraw', 'noaction', 'help', '', '', 0)
    call self.add('" A - Add connection', 'noaction', 'help', '', '', 0)
    call self.add('" H - Toggle database details', 'noaction', 'help', '', '', 0)
    call self.add('" r - Rename/Edit buffer/connection/saved query', 'noaction', 'help', '', '', 0)
    call self.add('" q - Close drawer', 'noaction', 'help', '', '', 0)
    call self.add('" <C-j>/<C-k> - Go to last/first sibling', 'noaction', 'help', '', '', 0)
    call self.add('" K/J - Go to prev/next sibling', 'noaction', 'help', '', '', 0)
    call self.add('" <C-p>/<C-n> - Go to parent/child node', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>W - (sql) Save currently opened query', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>E - (sql) Edit bind parameters in opened query', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>S - (sql) Execute query in visual or normal mode', 'noaction', 'help', '', '', 0)
    call self.add('" <C-]> - (.dbout) Go to entry from foreign key cell', 'noaction', 'help', '', '', 0)
    call self.add('" <motion>ic - (.dbout) Operator pending mapping for cell value', 'noaction', 'help', '', '', 0)
    call self.add('" <Leader>R - (.dbout) Toggle expanded view', 'noaction', 'help', '', '', 0)
    call self.add('', 'noaction', 'help', '', '', 0)
  endif
endfunction

function! s:drawer.add(label, action, type, icon, dbui_db_key_name, level, ...)
  let opts = extend({'label': a:label, 'action': a:action, 'type': a:type, 'icon': a:icon, 'dbui_db_key_name': a:dbui_db_key_name, 'level': a:level }, get(a:, '1', {}))
  call add(self.content, opts)
endfunction

function! s:drawer.add_db(db) abort
  " Check if this is a server-level connection in SSMS mode
  if get(a:db, 'is_server', 0) && g:db_ui_use_ssms_style
    return self.add_server(a:db)
  endif

  " Legacy database-level rendering
  let db_name = a:db.name

  if !empty(a:db.conn_error)
    let db_name .= ' '.g:db_ui_icons.connection_error
  elseif !empty(a:db.conn)
    let db_name .= ' '.g:db_ui_icons.connection_ok
  endif

  if self.show_details
    let db_name .= ' ('.a:db.scheme.' - '.a:db.source.')'
  endif

  call self.add(db_name, 'toggle', 'db', self.get_toggle_icon('db', a:db), a:db.key_name, 0, { 'expanded': a:db.expanded })
  if !a:db.expanded
    return a:db
  endif

  " Render sections based on g:db_ui_drawer_sections configuration
  for section in g:db_ui_drawer_sections
    if section ==# 'new_query'
      call self._render_new_query_section(a:db)
    elseif section ==# 'buffers' && !empty(a:db.buffers.list)
      call self._render_buffers_section(a:db)
    elseif section ==# 'saved_queries'
      call self._render_saved_queries_section(a:db)
    elseif section ==# 'schemas' || section ==# 'database_objects'
      call self._render_schemas_section(a:db)
    endif
  endfor
endfunction

" SSMS-style server rendering functions
function! s:drawer.add_server(server) abort
  let server_name = a:server.name

  if !empty(a:server.conn_error)
    let server_name .= ' '.g:db_ui_icons.connection_error
  elseif !empty(a:server.conn)
    let server_name .= ' '.g:db_ui_icons.connection_ok
  endif

  if self.show_details
    let server_name .= ' ('.a:server.scheme.' - '.a:server.source.' - Server)'
  endif

  call self.add(server_name, 'toggle', 'server', self.get_toggle_icon('db', a:server), a:server.key_name, 0, { 'expanded': a:server.expanded })

  if !a:server.expanded
    return a:server
  endif

  " Render sections based on g:db_ui_drawer_sections configuration (for server-level)
  for section in g:db_ui_drawer_sections
    if section ==# 'new_query'
      call self._render_new_query_section(a:server)
    elseif section ==# 'buffers' && !empty(a:server.buffers.list)
      call self._render_buffers_section(a:server)
    elseif section ==# 'saved_queries'
      call self._render_saved_queries_section(a:server)
    elseif section ==# 'schemas' || section ==# 'database_objects'
      " For SSMS-style, render databases instead of schemas
      call self.render_databases(a:server)
    endif
  endfor
endfunction

function! s:drawer.render_databases(server) abort
  let databases_icon = self.get_toggle_icon('schemas', a:server.databases)
  let db_count = len(a:server.databases.list)
  call self.add('Databases ('.db_count.')', 'toggle', 'server->databases', databases_icon, a:server.key_name, 1, { 'expanded': a:server.databases.expanded })

  if !a:server.databases.expanded
    return
  endif

  for db_name in a:server.databases.list
    let database = a:server.databases.items[db_name]
    call self.add_database(a:server, database, 2)
  endfor
endfunction

function! s:drawer.add_database(server, database, level) abort
  let db_name = a:database.name
  let db_icon = self.get_toggle_icon('schema', a:database)

  if !empty(a:database.conn_error)
    let db_name .= ' '.g:db_ui_icons.connection_error
  elseif !empty(a:database.conn)
    let db_name .= ' '.g:db_ui_icons.connection_ok
  endif

  call self.add(db_name, 'toggle', 'server->database->'.a:database.name, db_icon, a:server.key_name, a:level, { 'expanded': a:database.expanded, 'database_name': a:database.name })

  if !a:database.expanded
    return
  endif

  " Render object types
  call self.render_object_types(a:server, a:database, a:level + 1)
endfunction

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
    endif
  endfor
endfunction

function! s:drawer.render_object_type_group(server, database, label, object_type, object_data, level) abort
  let count = len(a:object_data.list)
  let icon = self.get_toggle_icon('tables', a:object_data)
  let type_path = 'server->database->'.a:database.name.'->'.a:object_type

  call self.add(a:label.' ('.count.')', 'toggle', type_path, icon, a:server.key_name, a:level, { 'expanded': a:object_data.expanded, 'database_name': a:database.name, 'object_type': a:object_type })

  if !a:object_data.expanded
    return
  endif

  " Handle empty object list
  let total_items = len(a:object_data.list)
  if total_items == 0
    call self.add('(No '.a:label.')', 'noaction', 'info', '  ', a:server.key_name, a:level + 1, {})
    return
  endif

  " Check if pagination is needed
  let max_per_page = g:db_ui_max_items_per_page
  let current_page = get(a:object_data, 'current_page', 1)
  let needs_pagination = max_per_page > 0 && total_items > max_per_page

  if needs_pagination
    " Calculate pagination info
    let total_pages = float2nr(ceil(total_items * 1.0 / max_per_page))
    let start_idx = (current_page - 1) * max_per_page
    let end_idx = min([start_idx + max_per_page, total_items]) - 1

    " Show pagination info
    let page_info = 'Page '.current_page.' of '.total_pages.' ('.total_items.' items)'
    call self.add(page_info, 'noaction', 'info', '  ', a:server.key_name, a:level + 1, {})

    " Show previous page option if not on first page
    if current_page > 1
      call self.add('◀ Previous Page', 'pagination', 'pagination_prev', '◀', a:server.key_name, a:level + 1, { 'database_name': a:database.name, 'object_type': a:object_type, 'direction': 'prev' })
    endif
  else
    let start_idx = 0
    let end_idx = total_items - 1
  endif

  " Render individual objects (paginated slice)
  for idx in range(start_idx, end_idx)
    let object_name = a:object_data.list[idx]
    let object_item = a:object_data.items[object_name]
    call self.add(object_name, 'toggle', type_path.'->'.object_name, self.get_toggle_icon('table', object_item), a:server.key_name, a:level + 1, { 'expanded': object_item.expanded, 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name })

    " Render object actions and structural info when expanded
    if object_item.expanded
      call self.render_object_items(a:server, a:database, object_item, a:object_type, a:level + 2)
    endif
  endfor

  if needs_pagination
    " Show next page option if not on last page
    if current_page < total_pages
      call self.add('Next Page ▶', 'pagination', 'pagination_next', '▶', a:server.key_name, a:level + 1, { 'database_name': a:database.name, 'object_type': a:object_type, 'direction': 'next' })
    endif
  endif
endfunction

function! s:drawer.render_object_items(server, database, object_item, object_type, level) abort
  let object_name = a:object_item.full_name
  " Parse schema and name from object_name (format: [schema].[name])
  " Use pattern matching to handle brackets correctly
  " Pattern explanation: [schema].[name] or schema.name, extract content inside brackets
  let match_result = matchlist(object_name, '^\[\?\([^\]]*\)\]\?\.\[\?\([^\]]*\)\]\?$')
  if !empty(match_result) && len(match_result) >= 3
    let schema = match_result[1]
    let name = match_result[2]
  else
    " Fallback: no schema prefix or malformed name
    let schema = 'dbo'
    let name = substitute(substitute(object_name, '^\[', '', ''), '\]$', '', '')
  endif

  " Get action helpers for this object type
  let helpers = db_ui#object_helpers#get(a:database.scheme, a:object_type)

  " Render actions based on object type
  if a:object_type ==# 'tables'
    " Render table actions and structural groups
    if has_key(helpers, 'SELECT')
      call self.add('SELECT', 'action', 'action', g:db_ui_icons.action_select, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'SELECT' })
    endif

    " Structural groups for tables
    if g:db_ui_ssms_show_columns
      let columns_group = a:object_item.structural_groups.columns
      call self.add('Columns', 'toggle', 'structural_group', g:db_ui_icons.columns, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'columns', 'expanded': columns_group.expanded })
      if columns_group.expanded
        call self.render_structural_group_items(columns_group.data, 'columns', a:server.key_name, a:level + 1)
      endif
    endif

    if g:db_ui_ssms_show_indexes
      let indexes_group = a:object_item.structural_groups.indexes
      call self.add('Indexes', 'toggle', 'structural_group', g:db_ui_icons.indexes, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'indexes', 'expanded': indexes_group.expanded })
      if indexes_group.expanded
        call self.render_structural_group_items(indexes_group.data, 'indexes', a:server.key_name, a:level + 1)
      endif
    endif

    if g:db_ui_ssms_show_keys
      let keys_group = a:object_item.structural_groups.keys
      call self.add('Keys', 'toggle', 'structural_group', g:db_ui_icons.keys, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'keys', 'expanded': keys_group.expanded })
      if keys_group.expanded
        call self.render_structural_group_items(keys_group.data, 'keys', a:server.key_name, a:level + 1)
      endif
    endif

    if g:db_ui_ssms_show_constraints
      let constraints_group = a:object_item.structural_groups.constraints
      call self.add('Constraints', 'toggle', 'structural_group', g:db_ui_icons.constraints, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'constraints', 'expanded': constraints_group.expanded })
      if constraints_group.expanded
        call self.render_structural_group_items(constraints_group.data, 'constraints', a:server.key_name, a:level + 1)
      endif
    endif

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif

  elseif a:object_type ==# 'views'
    " Render view actions
    if has_key(helpers, 'SELECT')
      call self.add('SELECT', 'action', 'action', g:db_ui_icons.action_select, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'SELECT' })
    endif

    if g:db_ui_ssms_show_columns
      let columns_group = a:object_item.structural_groups.columns
      call self.add('Columns', 'toggle', 'structural_group', g:db_ui_icons.columns, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'columns', 'expanded': columns_group.expanded })
      if columns_group.expanded
        call self.render_structural_group_items(columns_group.data, 'columns', a:server.key_name, a:level + 1)
      endif
    endif

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif

  elseif a:object_type ==# 'procedures'
    " Render procedure actions
    if has_key(helpers, 'EXEC')
      call self.add('EXEC', 'action', 'action', g:db_ui_icons.action_exec, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'EXEC' })
    endif

    let parameters_group = a:object_item.structural_groups.parameters
    call self.add('Parameters', 'toggle', 'structural_group', g:db_ui_icons.parameters, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'parameters', 'expanded': parameters_group.expanded })
    if parameters_group.expanded
      call self.render_structural_group_items(parameters_group.data, 'parameters', a:server.key_name, a:level + 1)
    endif

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif

  elseif a:object_type ==# 'functions'
    " Render function actions
    if has_key(helpers, 'SELECT')
      call self.add('SELECT', 'action', 'action', g:db_ui_icons.action_select, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'SELECT' })
    endif

    let parameters_group = a:object_item.structural_groups.parameters
    call self.add('Parameters', 'toggle', 'structural_group', g:db_ui_icons.parameters, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'group_type': 'parameters', 'expanded': parameters_group.expanded })
    if parameters_group.expanded
      call self.render_structural_group_items(parameters_group.data, 'parameters', a:server.key_name, a:level + 1)
    endif

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:server.key_name, a:level, { 'database_name': a:database.name, 'object_type': a:object_type, 'object_name': object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif
  endif
endfunction

function! s:drawer.render_structural_group_items(data, group_type, db_key_name, level) abort
  " Render individual items in a structural group with aligned columns
  if empty(a:data)
    call self.add('(No '.a:group_type.')', 'noaction', 'info', '', a:db_key_name, a:level)
    return
  endif

  " Calculate column widths for alignment
  let max_widths = []
  let formatted_rows = []

  " First pass: collect all rows and calculate max widths
  for row in a:data
    if type(row) ==? type([])
      " Ensure we have enough width slots
      while len(max_widths) < len(row)
        call add(max_widths, 0)
      endwhile

      " Calculate widths for this row
      for idx in range(len(row))
        let val = row[idx]
        if len(val) > max_widths[idx]
          let max_widths[idx] = len(val)
        endif
      endfor

      call add(formatted_rows, row)
    else
      " Non-array row
      call add(formatted_rows, [row])
      if len(max_widths) < 1
        call add(max_widths, 0)
      endif
      if len(row) > max_widths[0]
        let max_widths[0] = len(row)
      endif
    endif
  endfor

  " Second pass: render with aligned columns
  for row in formatted_rows
    let parts = []

    for idx in range(len(row))
      let val = row[idx]
      let width = idx < len(max_widths) ? max_widths[idx] : len(val)
      " Pad with spaces to align
      let padded = val . repeat(' ', width - len(val))
      call add(parts, padded)
    endfor

    let display = join(parts, ' | ')

    " Set appropriate item type
    let item_type = 'item'
    if a:group_type ==# 'columns'
      let item_type = 'column'
    elseif a:group_type ==# 'indexes'
      let item_type = 'index'
    elseif a:group_type ==# 'constraints'
      let item_type = 'constraint'
    elseif a:group_type ==# 'parameters'
      let item_type = 'parameter'
    elseif a:group_type ==# 'keys'
      let item_type = 'key'
    endif

    call self.add(display, 'noaction', item_type, '', a:db_key_name, a:level)
  endfor
endfunction

function! s:drawer.render_tables(tables, db, path, level, schema) abort
  if !a:tables.expanded
    return
  endif
  if type(g:Db_ui_table_name_sorter) ==? type(function('tr'))
    let tables_list = call(g:Db_ui_table_name_sorter, [a:tables.list])
  else
    let tables_list = a:tables.list
  endif
  for table in tables_list
    call self.add(table, 'toggle', a:path.'->'.table, self.get_toggle_icon('table', a:tables.items[table]), a:db.key_name, a:level, { 'expanded': a:tables.items[table].expanded })
    if a:tables.items[table].expanded
      for [helper_name, helper] in items(a:db.table_helpers)
        call self.add(helper_name, 'open', 'table', g:db_ui_icons.tables, a:db.key_name, a:level + 1, {'table': table, 'content': helper, 'schema': a:schema })
      endfor
    endif
  endfor
endfunction

function! s:drawer.toggle_line(edit_action) abort
  let item = self.get_current_item()
  if item.action ==? 'noaction'
    return
  endif

  if item.action ==? 'call_method'
    return s:method(item.type)
  endif

  if item.type ==? 'dbout'
    call self.get_query().focus_window()
    silent! exe 'pedit' item.file_path
    return
  endif

  if item.action ==? 'open'
    return self.get_query().open(item, a:edit_action)
  endif

  " Handle SSMS-style object actions (SELECT, EXEC, ALTER, DROP, DEPENDENCIES)
  if item.action ==? 'action'
    return self.execute_object_action(item, a:edit_action)
  endif

  " Handle pagination actions
  if item.action ==? 'pagination'
    return self.handle_pagination(item)
  endif

  let db = self.dbui.dbs[item.dbui_db_key_name]

  " Handle SSMS-style structural groups (Columns, Indexes, etc.)
  if item.type ==? 'structural_group'
    return self.toggle_structural_group(db, item)
  endif

  " Handle SSMS-style server/database/object type navigation
  if item.type ==? 'server'
    let db.expanded = !db.expanded
    call self.toggle_db(db)
    return self.render()
  endif

  if item.type ==? 'server->databases'
    let db.databases.expanded = !db.databases.expanded
    if db.databases.expanded && empty(db.databases.list)
      call self.dbui.populate_databases(db)
    endif
    return self.render()
  endif

  if stridx(item.type, 'server->database->') == 0
    return self.toggle_ssms_item(db, item, a:edit_action)
  endif

  " Handle SSMS-style database-level object types (db->tables, db->views, etc.)
  if stridx(item.type, 'db->') == 0
    return self.toggle_db_level_ssms_item(db, item, a:edit_action)
  endif

  " Legacy database-level navigation
  let tree = db
  if item.type !=? 'db'
    let tree = self.get_nested(db, item.type)
  endif

  let tree.expanded = !tree.expanded

  if item.type ==? 'db'
    call self.toggle_db(db)
  endif

  return self.render()
endfunction

function! s:drawer.toggle_ssms_item(server, item, edit_action) abort
  let parts = split(a:item.type, '->')

  " server->database->DatabaseName
  if len(parts) == 3
    let db_name = a:item.database_name
    let database = a:server.databases.items[db_name]
    let database.expanded = !database.expanded

    if database.expanded
      call self.dbui.connect_to_database(a:server, db_name)
    endif

    return self.render()
  endif

  " server->database->DatabaseName->tables/views/procedures/functions
  if len(parts) == 4
    let db_name = a:item.database_name
    let database = a:server.databases.items[db_name]
    let object_type = a:item.object_type

    if object_type ==# 'tables'
      let database.tables.expanded = !database.tables.expanded
      if database.tables.expanded
        call self.populate_tables(database)
      endif
    else
      let database.object_types[object_type].expanded = !database.object_types[object_type].expanded
      if database.object_types[object_type].expanded
        call self.dbui.populate_object_type(database, object_type, db_ui#schemas#get(database.scheme))
      endif
    endif

    return self.render()
  endif

  " server->database->DatabaseName->object_type->ObjectName (individual object)
  if len(parts) == 5
    let db_name = a:item.database_name
    let database = a:server.databases.items[db_name]
    let object_type = a:item.object_type
    let object_name = a:item.object_name

    if object_type ==# 'tables'
      let database.tables.items[object_name].expanded = !database.tables.items[object_name].expanded
    else
      let database.object_types[object_type].items[object_name].expanded = !database.object_types[object_type].items[object_name].expanded
    endif

    return self.render()
  endif

  return self.render()
endfunction

function! s:drawer.handle_pagination(item) abort
  let db = self.dbui.dbs[a:item.dbui_db_key_name]
  let db_name = a:item.database_name
  let object_type = a:item.object_type
  let direction = a:item.direction

  " Determine if server-level or database-level connection
  if has_key(db, 'databases') && has_key(db.databases.items, db_name)
    " Server-level connection
    let database = db.databases.items[db_name]
    if object_type ==# 'tables'
      let object_data = database.tables
    else
      let object_data = database.object_types[object_type]
    endif
  else
    " Database-level connection
    if object_type ==# 'tables'
      let object_data = db.tables
    else
      let object_data = db.object_types[object_type]
    endif
  endif

  " Update current page
  let current_page = get(object_data, 'current_page', 1)
  if direction ==# 'next'
    let object_data.current_page = current_page + 1
  elseif direction ==# 'prev'
    let object_data.current_page = max([1, current_page - 1])
  endif

  return self.render()
endfunction

function! s:drawer.toggle_db_level_ssms_item(db, item, edit_action) abort
  let parts = split(a:item.type, '->')

  " db->tables, db->views, db->procedures, db->functions
  if len(parts) == 2
    let object_type = parts[1]

    if object_type ==# 'tables'
      let a:db.tables.expanded = !a:db.tables.expanded
      if a:db.tables.expanded
        call self.populate_tables(a:db)
      endif
    elseif has_key(a:db.object_types, object_type)
      let a:db.object_types[object_type].expanded = !a:db.object_types[object_type].expanded
      if a:db.object_types[object_type].expanded
        call self.dbui.populate_object_type(a:db, object_type, db_ui#schemas#get(a:db.scheme))
      endif
    endif

    return self.render()
  endif

  " db->views->ViewName, db->procedures->ProcName, db->functions->FuncName
  if len(parts) == 3
    let object_type = parts[1]
    let object_name = parts[2]

    if has_key(a:db.object_types, object_type) && has_key(a:db.object_types[object_type].items, object_name)
      let object_item = a:db.object_types[object_type].items[object_name]
      let object_item.expanded = !object_item.expanded
    endif

    return self.render()
  endif

  return self.render()
endfunction

function! s:drawer.toggle_structural_group(db, item) abort
  " Toggle structural groups like Columns, Indexes, Keys, Constraints, Parameters
  let database = a:db
  if has_key(a:item, 'database_name') && has_key(a:db, 'databases') && has_key(a:db.databases.items, a:item.database_name)
    let database = a:db.databases.items[a:item.database_name]
  endif

  " Find the object item that contains this structural group
  let object_type = a:item.object_type
  let object_name = a:item.object_name

  " Get the object item
  let object_item = {}
  if object_type ==# 'tables'
    if has_key(database.tables.items, object_name)
      let object_item = database.tables.items[object_name]
    endif
  elseif has_key(database, 'object_types') && has_key(database.object_types, object_type) && has_key(database.object_types[object_type].items, object_name)
    let object_item = database.object_types[object_type].items[object_name]
  endif

  if empty(object_item)
    return db_ui#notifications#error('Object not found: '.object_name)
  endif

  " Toggle the structural group
  let group_type = a:item.group_type
  let group = object_item.structural_groups[group_type]
  let group.expanded = !group.expanded

  " Fetch data if expanding for the first time
  if group.expanded && empty(group.data)
    let group.data = self.dbui.populate_structural_group(database, a:item.schema, a:item.name, group_type)
  endif

  return self.render()
endfunction

function! s:drawer.execute_object_action(item, edit_action) abort
  " Execute SSMS-style object actions (SELECT, EXEC, ALTER, DROP, DEPENDENCIES)
  let db = self.dbui.dbs[a:item.dbui_db_key_name]

  " Get the database for server-level connections
  let database = db
  if has_key(a:item, 'database_name') && has_key(db, 'databases') && has_key(db.databases.items, a:item.database_name)
    let database = db.databases.items[a:item.database_name]
  endif

  " Build variable substitution dict
  let vars = {
        \ 'schema': get(a:item, 'schema', 'dbo'),
        \ 'table': get(a:item, 'name', ''),
        \ 'view': get(a:item, 'name', ''),
        \ 'procedure': get(a:item, 'name', ''),
        \ 'function': get(a:item, 'name', ''),
        \ }

  " Get the SQL template for this action
  let sql = db_ui#object_helpers#get_action(database.scheme, a:item.object_type, a:item.action_type, vars)

  if empty(sql)
    return db_ui#notifications#error('No action template found for '.a:item.action_type.' on '.a:item.object_type)
  endif

  " For ALTER action, execute the query and populate buffer with the result
  if a:item.action_type ==# 'ALTER'
    " Execute the query to get the object definition
    try
      " For server-level connections, we need to connect to the specific database
      " For database-level connections, use the existing connection
      let query_connection = db

      if has_key(a:item, 'database_name') && has_key(db, 'databases')
        " Build a database-specific connection URL
        let db_url = self.dbui.build_database_url(db.url, a:item.database_name)
        let temp_conn = db#connect(db_url)

        " Create a temporary db object for querying
        let query_connection = {
              \ 'conn': temp_conn,
              \ 'scheme': db.scheme,
              \ 'name': a:item.database_name
              \ }
      endif

      " Use db#systemlist to execute the query (without USE statement for temp connection)
      let scheme_info = db_ui#schemas#get(query_connection.scheme)
      let result = db_ui#schemas#query(query_connection, scheme_info, sql)

      " Parse the result to extract the definition
      let definition = self.parse_alter_result(result, database.scheme)

      if empty(definition)
        return db_ui#notifications#error('Could not retrieve definition for '.a:item.object_name)
      endif

      " Create buffer with the object definition
      let buffer_item = {
            \ 'action': 'open',
            \ 'type': 'query',
            \ 'label': a:item.action_type.' - '.a:item.object_name,
            \ 'dbui_db_key_name': db.key_name,
            \ 'content': definition,
            \ }

      return self.get_query().open(buffer_item, a:edit_action)
    catch /.*/
      return db_ui#notifications#error('Error fetching definition: '.v:exception)
    endtry
  endif

  " For other actions (SELECT, EXEC, DROP, DEPENDENCIES), use the query as-is
  " For server-level connections, prepend database context switch
  if has_key(a:item, 'database_name') && has_key(db, 'databases')
    let context_switch = self.get_database_context_switch(db.scheme, a:item.database_name)
    if !empty(context_switch)
      let sql = context_switch . "\n\n" . sql
    endif
  endif

  " Create a buffer item to open the query
  let buffer_item = {
        \ 'action': 'open',
        \ 'type': 'query',
        \ 'label': a:item.action_type.' - '.a:item.object_name,
        \ 'dbui_db_key_name': db.key_name,
        \ 'content': sql,
        \ }

  " Open the query buffer
  return self.get_query().open(buffer_item, a:edit_action)
endfunction

function! s:drawer.parse_alter_result(result, scheme) abort
  " Parse the query result to extract object definition
  let scheme = tolower(a:scheme)

  " Result is a list of lines from the query execution
  if empty(a:result)
    return ''
  endif

  " For SQL Server, the result format varies by query type
  if scheme =~? '^sqlserver' || scheme =~? '^mssql'
    " SQL Server sys.sql_modules returns definition directly without header/separator
    " Format:
    " - empty line
    " - data rows (the actual definition, may span multiple lines)
    " - empty lines
    " - metadata line "(N rows affected)"
    let definition_lines = []

    for line in a:result
      " Stop at metadata lines like "(1 rows affected)"
      if line =~? '^(\d\+ rows\? affected)'
        break
      endif

      " Collect all lines (including empty lines for formatting)
      " The definition includes the full CREATE statement
      call add(definition_lines, line)
    endfor

    " Remove leading empty lines
    while !empty(definition_lines) && empty(trim(definition_lines[0]))
      call remove(definition_lines, 0)
    endwhile

    " Remove trailing empty lines
    while !empty(definition_lines) && empty(trim(definition_lines[-1]))
      call remove(definition_lines, -1)
    endwhile

    " If we have definition lines, join them
    if !empty(definition_lines)
      return join(definition_lines, "\n")
    endif

    return ''
  elseif scheme =~? '^postgres'
    " PostgreSQL pg_get_viewdef/pg_get_functiondef returns clean definition
    " Skip header and separator, get the definition
    let definition_lines = []
    let skip_lines = 2  " Skip header and separator

    for idx in range(len(a:result))
      if idx < skip_lines
        continue
      endif

      let line = a:result[idx]
      if !empty(trim(line))
        call add(definition_lines, line)
      endif
    endfor

    return join(definition_lines, "\n")
  elseif scheme =~? '^mysql' || scheme =~? '^mariadb'
    " MySQL SHOW CREATE returns "Create Table" or "Create View" in second column
    " Format: TableName | CREATE TABLE ...
    let definition_lines = []
    let skip_lines = 3  " Skip header, separator, and column names

    for idx in range(len(a:result))
      if idx < skip_lines
        continue
      endif

      let line = a:result[idx]
      " Split by tab or pipe and get the second column
      let parts = split(line, '\t\|\|')
      if len(parts) >= 2
        call add(definition_lines, parts[1])
      endif
    endfor

    return join(definition_lines, "\n")
  else
    " Generic: skip first 2 lines (header and separator) and return the rest
    return join(a:result[2:], "\n")
  endif
endfunction

function! s:drawer.get_database_context_switch(scheme, database_name) abort
  " Generate database context switch statement based on database type
  let scheme = tolower(a:scheme)

  if scheme =~? '^sqlserver' || scheme =~? '^mssql'
    " SQL Server uses USE [database]; GO
    return "USE [" . a:database_name . "];\nGO"
  elseif scheme =~? '^postgres'
    " PostgreSQL: Connection switching not supported in query buffers
    " Would need to reconnect with different database
    return "-- Connected to database: " . a:database_name
  elseif scheme =~? '^mysql' || scheme =~? '^mariadb'
    " MySQL/MariaDB uses USE `database`;
    return "USE `" . a:database_name . "`;"
  else
    " Other databases - add a comment
    return "-- Database: " . a:database_name
  endif
endfunction

function! s:drawer.get_query() abort
  if empty(self.query)
    let self.query = db_ui#query#new(self)
  endif
  return self.query
endfunction

function! s:drawer.delete_line() abort
  let item = self.get_current_item()

  if item.action ==? 'noaction'
    return
  endif

  if item.action ==? 'toggle' && item.type ==? 'db'
    let db = self.dbui.dbs[item.dbui_db_key_name]
    if db.source !=? 'file'
      return db_ui#notifications#error('Cannot delete this connection.')
    endif
    return self.delete_connection(db)
  endif

  if item.action !=? 'open' || item.type !=? 'buffer'
    return
  endif

  let db = self.dbui.dbs[item.dbui_db_key_name]

  if has_key(item, 'saved')
    let choice = confirm('Are you sure you want to delete this saved query?', "&Yes\n&No")
    if choice !=? 1
      return
    endif

    call delete(item.file_path)
    call remove(db.saved_queries.list, index(db.saved_queries.list, item.file_path))
    call filter(db.buffers.list, 'v:val !=? item.file_path')
    call db_ui#notifications#info('Deleted.')
  endif

  if self.dbui.is_tmp_location_buffer(db, item.file_path)
    let choice = confirm('Are you sure you want to delete query?', "&Yes\n&No")
    if choice !=? 1
      return
    endif

    call delete(item.file_path)
    call filter(db.buffers.list, 'v:val !=? item.file_path')
    call db_ui#notifications#info('Deleted.')
  endif

  let win = bufwinnr(item.file_path)
  if  win > -1
    silent! exe win.'wincmd w'
    silent! exe 'b#'
  endif

  silent! exe 'bw!'.bufnr(item.file_path)
  call self.focus()
  call self.render()
endfunction

function! s:drawer.toggle_db(db) abort
  if !a:db.expanded
    return a:db
  endif

  " Handle server-level connections in SSMS mode
  if get(a:db, 'is_server', 0) && g:db_ui_use_ssms_style
    return self.toggle_server(a:db)
  endif

  " Legacy database-level connection handling
  call self.load_saved_queries(a:db)

  call self.dbui.connect(a:db)

  if !empty(a:db.conn)
    call self.populate(a:db)
  endif
endfunction

function! s:drawer.toggle_server(server) abort
  if !a:server.expanded
    return a:server
  endif

  call self.dbui.connect(a:server)

  if !empty(a:server.conn)
    call self.dbui.populate_databases(a:server)
  endif
endfunction

function! s:drawer.populate(db) abort
  if empty(a:db.conn) && a:db.conn_tried
    call self.dbui.connect(a:db)
  endif
  if a:db.schema_support
    return self.populate_schemas(a:db)
  endif
  return self.populate_tables(a:db)
endfunction

function! s:drawer.load_saved_queries(db) abort
  if !empty(a:db.save_path)
    let a:db.saved_queries.list = split(glob(printf('%s/*', a:db.save_path)), "\n")
  endif
endfunction

function! s:drawer.populate_tables(db) abort
  let a:db.tables.list = []
  if empty(a:db.conn)
    return a:db
  endif

  " For SSMS-style mode with schema support, use schema queries
  if g:db_ui_use_ssms_style && g:db_ui_show_schema_prefix
    let scheme_info = db_ui#schemas#get(a:db.scheme)
    if has_key(scheme_info, 'schemes_tables_query')
      try
        " Build query with database filter for MySQL/MariaDB and SQL Server
        let query = scheme_info.schemes_tables_query
        if (a:db.scheme =~? '^mysql' || a:db.scheme =~? '^mariadb') && has_key(a:db, 'name')
          " For MySQL, filter by TABLE_SCHEMA (database name) and exclude system schemas
          let query = query . ' WHERE table_schema = ''' . a:db.name . ''' AND table_schema NOT IN (''information_schema'', ''mysql'', ''performance_schema'', ''sys'')'
        elseif (a:db.scheme =~? '^sqlserver' || a:db.scheme =~? '^mssql') && has_key(a:db, 'name')
          " For SQL Server, filter by TABLE_CATALOG (database name)
          let query = query . ' WHERE TABLE_CATALOG = ''' . a:db.name . ''''
        endif

        let result = db_ui#schemas#query(a:db, scheme_info, query)
        let parsed_result = scheme_info.parse_results(result, 2)

        for row in parsed_result
          if type(row) ==? type([]) && len(row) >= 2
            let schema_name = trim(row[0])
            let table_name = trim(row[1])

            " Skip header row (column names like TABLE_SCHEMA, TABLE_NAME)
            if schema_name =~? '^TABLE_SCHEMA$' || schema_name =~? '^table_schema$'
              continue
            endif

            " Skip empty rows
            if empty(schema_name) || empty(table_name)
              continue
            endif

            let full_name = '['.schema_name.'].['.table_name.']'
            call add(a:db.tables.list, full_name)
          endif
        endfor

        " Sort by schema then table name
        call sort(a:db.tables.list)
        call self.populate_table_items(a:db.tables)
        return a:db
      catch /.*/
        " Fall back to adapter method if schema query fails
      endtry
    endif
  endif

  " Legacy method using adapter
  let tables = db#adapter#call(a:db.conn, 'tables', [a:db.conn], [])

  let a:db.tables.list = tables
  " Fix issue with sqlite tables listing as strings with spaces
  if a:db.scheme =~? '^sqlite' && len(a:db.tables.list) >=? 0
    let temp_table_list = []

    for table_index in a:db.tables.list
      let temp_table_list += map(split(copy(table_index)), 'trim(v:val)')
    endfor

    let a:db.tables.list = sort(temp_table_list)
  endif

  if a:db.scheme =~? '^mysql'
    call filter(a:db.tables.list, 'v:val !~? "mysql: [Warning\\]" && v:val !~? "Tables_in_"')
  endif

  call self.populate_table_items(a:db.tables)
  return a:db
endfunction

function! s:drawer.populate_table_items(tables) abort
  for table in a:tables.list
    if !has_key(a:tables.items, table)
      " Parse schema and name from table (format: [schema].[name] or just name)
      let parts = split(table, '\.')
      let schema_name = len(parts) > 1 ? substitute(parts[0], '^\[', '', '') : 'dbo'
      let schema_name = substitute(schema_name, '\]$', '', '')
      let object_name = len(parts) > 1 ? substitute(parts[1], '^\[', '', '') : table
      let object_name = substitute(object_name, '\]$', '', '')

      let a:tables.items[table] = {
            \ 'schema': schema_name,
            \ 'name': object_name,
            \ 'full_name': table,
            \ 'expanded': 0,
            \ 'structural_groups': {
            \   'columns': {'expanded': 0, 'data': []},
            \   'indexes': {'expanded': 0, 'data': []},
            \   'keys': {'expanded': 0, 'data': []},
            \   'primary_keys': {'expanded': 0, 'data': []},
            \   'foreign_keys': {'expanded': 0, 'data': []},
            \   'constraints': {'expanded': 0, 'data': []},
            \   'parameters': {'expanded': 0, 'data': []},
            \ },
            \ }
    endif
  endfor
endfunction

function! s:drawer.populate_schemas(db) abort
  let a:db.schemas.list = []
  if empty(a:db.conn)
    return a:db
  endif
  let scheme = db_ui#schemas#get(a:db.scheme)
  let schemas = scheme.parse_results(db_ui#schemas#query(a:db, scheme, scheme.schemes_query), 1)
  let tables = scheme.parse_results(db_ui#schemas#query(a:db, scheme, scheme.schemes_tables_query), 2)
  let schemas = filter(schemas, {i, v -> !self._is_schema_ignored(v)})
  let tables_by_schema = {}
  for [scheme_name, table] in tables
    if self._is_schema_ignored(scheme_name)
      continue
    endif
    if !has_key(tables_by_schema, scheme_name)
      let tables_by_schema[scheme_name] = []
    endif
    call add(tables_by_schema[scheme_name], table)
    call add(a:db.tables.list, table)
  endfor
  let a:db.schemas.list = schemas
  for schema in schemas
    if !has_key(a:db.schemas.items, schema)
      let a:db.schemas.items[schema] = {
            \ 'expanded': 0,
            \ 'tables': {
            \   'expanded': 1,
            \   'list': [],
            \   'items': {},
            \ },
            \ }

    endif
    let a:db.schemas.items[schema].tables.list = sort(get(tables_by_schema, schema, []))
    call self.populate_table_items(a:db.schemas.items[schema].tables)
  endfor
  return a:db
endfunction

function! s:drawer.get_toggle_icon(type, item) abort
  if a:item.expanded
    return g:db_ui_icons.expanded[a:type]
  endif

  return g:db_ui_icons.collapsed[a:type]
endfunction

function! s:drawer.get_nested(obj, val, ...) abort
  let default = get(a:, '1', 0)
  let items = split(a:val, '->')
  let result = copy(a:obj)

  for item in items
    if !has_key(result, item)
      let result = default
      break
    endif
    let result = result[item]
  endfor

  return result
endfunction

function! s:drawer.get_buffer_name(db, buffer)
  let name = fnamemodify(a:buffer, ':t')
  let is_tmp = self.dbui.is_tmp_location_buffer(a:db, a:buffer)

  if !is_tmp
    return name
  endif

  if fnamemodify(name, ':r') ==? 'db_ui'
    let name = fnamemodify(name, ':e')
  endif

  return substitute(name, '^'.db_ui#utils#slug(a:db.name).'-', '', '')
endfunction

function! s:drawer._render_new_query_section(db) abort
  call self.add('New query', 'open', 'query', g:db_ui_icons.new_query, a:db.key_name, 1)
endfunction

function! s:drawer._render_buffers_section(db) abort
  call self.add('Buffers ('.len(a:db.buffers.list).')', 'toggle', 'buffers', self.get_toggle_icon('buffers', a:db.buffers), a:db.key_name, 1, { 'expanded': a:db.buffers.expanded })
  if a:db.buffers.expanded
    for buf in a:db.buffers.list
      let buflabel = self.get_buffer_name(a:db, buf)
      if self.dbui.is_tmp_location_buffer(a:db, buf)
        let buflabel .= ' *'
      endif
      call self.add(buflabel, 'open', 'buffer', g:db_ui_icons.buffers, a:db.key_name, 2, { 'file_path': buf })
    endfor
  endif
endfunction

function! s:drawer._render_saved_queries_section(db) abort
  call self.add('Saved queries ('.len(a:db.saved_queries.list).')', 'toggle', 'saved_queries', self.get_toggle_icon('saved_queries', a:db.saved_queries), a:db.key_name, 1, { 'expanded': a:db.saved_queries.expanded })
  if a:db.saved_queries.expanded
    for saved_query in a:db.saved_queries.list
      call self.add(fnamemodify(saved_query, ':t'), 'open', 'buffer', g:db_ui_icons.saved_query, a:db.key_name, 2, { 'file_path': saved_query, 'saved': 1 })
    endfor
  endif
endfunction

function! s:drawer._render_schemas_section(db) abort
  " For SSMS-style mode on database-level connections, render object types
  if g:db_ui_use_ssms_style && has_key(a:db, 'object_types')
    " Render TABLES
    let tables_count = len(a:db.tables.items)
    call self.add('TABLES ('.tables_count.')', 'toggle', 'db->tables', self.get_toggle_icon('tables', a:db.tables), a:db.key_name, 1, { 'expanded': a:db.tables.expanded })
    if a:db.tables.expanded
      call self.render_tables(a:db.tables, a:db, 'tables->items', 2, '')
    endif

    " Render VIEWS
    let views_count = len(a:db.object_types.views.items)
    call self.add('VIEWS ('.views_count.')', 'toggle', 'db->views', self.get_toggle_icon('tables', a:db.object_types.views), a:db.key_name, 1, { 'expanded': a:db.object_types.views.expanded })
    if a:db.object_types.views.expanded
      for view_name in a:db.object_types.views.list
        let view_item = a:db.object_types.views.items[view_name]
        call self.add(view_name, 'toggle', 'db->views->'.view_name, self.get_toggle_icon('table', view_item), a:db.key_name, 2, { 'expanded': view_item.expanded })
        if view_item.expanded
          call self.render_db_level_object_items(a:db, view_name, 'views', 3)
        endif
      endfor
    endif

    " Render PROCEDURES
    let procs_count = len(a:db.object_types.procedures.items)
    call self.add('PROCEDURES ('.procs_count.')', 'toggle', 'db->procedures', self.get_toggle_icon('tables', a:db.object_types.procedures), a:db.key_name, 1, { 'expanded': a:db.object_types.procedures.expanded })
    if a:db.object_types.procedures.expanded
      for proc_name in a:db.object_types.procedures.list
        let proc_item = a:db.object_types.procedures.items[proc_name]
        call self.add(proc_name, 'toggle', 'db->procedures->'.proc_name, self.get_toggle_icon('table', proc_item), a:db.key_name, 2, { 'expanded': proc_item.expanded })
        if proc_item.expanded
          call self.render_db_level_object_items(a:db, proc_name, 'procedures', 3)
        endif
      endfor
    endif

    " Render FUNCTIONS
    let funcs_count = len(a:db.object_types.functions.items)
    call self.add('FUNCTIONS ('.funcs_count.')', 'toggle', 'db->functions', self.get_toggle_icon('tables', a:db.object_types.functions), a:db.key_name, 1, { 'expanded': a:db.object_types.functions.expanded })
    if a:db.object_types.functions.expanded
      for func_name in a:db.object_types.functions.list
        let func_item = a:db.object_types.functions.items[func_name]
        call self.add(func_name, 'toggle', 'db->functions->'.func_name, self.get_toggle_icon('table', func_item), a:db.key_name, 2, { 'expanded': func_item.expanded })
        if func_item.expanded
          call self.render_db_level_object_items(a:db, func_name, 'functions', 3)
        endif
      endfor
    endif
  elseif a:db.schema_support
    " Legacy schema support
    call self.add('Schemas ('.len(a:db.schemas.items).')', 'toggle', 'schemas', self.get_toggle_icon('schemas', a:db.schemas), a:db.key_name, 1, { 'expanded': a:db.schemas.expanded })
    if a:db.schemas.expanded
      for schema in a:db.schemas.list
        let schema_item = a:db.schemas.items[schema]
        let tables = schema_item.tables
        call self.add(schema.' ('.len(tables.items).')', 'toggle', 'schemas->items->'.schema, self.get_toggle_icon('schema', schema_item), a:db.key_name, 2, { 'expanded': schema_item.expanded })
        if schema_item.expanded
          call self.render_tables(tables, a:db,'schemas->items->'.schema.'->tables->items', 3, schema)
        endif
      endfor
    endif
  else
    " Legacy table-only support
    call self.add('Tables ('.len(a:db.tables.items).')', 'toggle', 'tables', self.get_toggle_icon('tables', a:db.tables), a:db.key_name, 1, { 'expanded': a:db.tables.expanded })
    call self.render_tables(a:db.tables, a:db, 'tables->items', 2, '')
  endif
endfunction

function! s:drawer.render_db_level_object_items(db, object_name, object_type, level) abort
  " Render actions and structural groups for database-level SSMS objects
  " Parse schema and name from object_name (format: [schema].[name])
  let parts = split(a:object_name, '\.')
  let schema = len(parts) > 1 ? substitute(parts[0], '^\[', '', '') : 'dbo'
  let schema = substitute(schema, '\]$', '', '')
  let name = len(parts) > 1 ? substitute(parts[1], '^\[', '', '') : a:object_name
  let name = substitute(name, '\]$', '', '')

  " Get action helpers for this object type
  let helpers = db_ui#object_helpers#get(a:db.scheme, a:object_type)

  " Render actions based on object type (same logic as render_object_items but for db-level)
  if a:object_type ==# 'views'
    if has_key(helpers, 'SELECT')
      call self.add('SELECT', 'action', 'action', g:db_ui_icons.action_select, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'SELECT' })
    endif

    if g:db_ui_ssms_show_columns
      call self.add('Columns', 'toggle', 'structural_group', g:db_ui_icons.columns, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'group_type': 'columns', 'expanded': 0 })
    endif

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif

  elseif a:object_type ==# 'procedures'
    if has_key(helpers, 'EXEC')
      call self.add('EXEC', 'action', 'action', g:db_ui_icons.action_exec, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'EXEC' })
    endif

    call self.add('Parameters', 'toggle', 'structural_group', g:db_ui_icons.parameters, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'group_type': 'parameters', 'expanded': 0 })

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif

  elseif a:object_type ==# 'functions'
    if has_key(helpers, 'SELECT')
      call self.add('SELECT', 'action', 'action', g:db_ui_icons.action_select, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'SELECT' })
    endif

    call self.add('Parameters', 'toggle', 'structural_group', g:db_ui_icons.parameters, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'group_type': 'parameters', 'expanded': 0 })

    if has_key(helpers, 'ALTER')
      call self.add('ALTER', 'action', 'action', g:db_ui_icons.action_alter, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'ALTER' })
    endif

    if has_key(helpers, 'DROP')
      call self.add('DROP', 'action', 'action', g:db_ui_icons.action_drop, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DROP' })
    endif

    if g:db_ui_ssms_show_dependencies && has_key(helpers, 'DEPENDENCIES')
      call self.add('DEPENDENCIES', 'action', 'action', g:db_ui_icons.action_dependencies, a:db.key_name, a:level, { 'object_type': a:object_type, 'object_name': a:object_name, 'schema': schema, 'name': name, 'action_type': 'DEPENDENCIES' })
    endif
  endif
endfunction

function! s:drawer._is_schema_ignored(schema_name)
  for ignored_schema in g:db_ui_hide_schemas
    if match(a:schema_name, ignored_schema) > -1
      return 1
    endif
  endfor
  return 0
endfunction

function! s:sort_dbout(a1, a2)
  return str2nr(fnamemodify(a:a1, ':t:r')) - str2nr(fnamemodify(a:a2, ':t:r'))
endfunction
