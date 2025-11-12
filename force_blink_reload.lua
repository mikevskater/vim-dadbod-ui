-- Force blink.cmp to reload and re-register sources

print("=== Forcing blink.cmp reload ===\n")

-- Step 1: Unload blink modules
print("1. Unloading blink.cmp modules...")
package.loaded['blink.cmp'] = nil
package.loaded['blink.cmp.config'] = nil
package.loaded['blink.cmp.sources'] = nil
package.loaded['blink.cmp.sources.dadbod'] = nil
print("   ✓ Modules unloaded\n")

-- Step 2: Reload blink.cmp
print("2. Reloading blink.cmp...")
local ok, blink = pcall(require, 'blink.cmp')
if not ok then
  print("   ✗ FAIL: Could not reload blink.cmp")
  print("   Error: " .. tostring(blink))
  return
end
print("   ✓ blink.cmp reloaded\n")

-- Step 3: Check if dadbod source is now registered
print("3. Checking source registration...")
local config = blink.config or {}
local sources = config.sources or {}
local providers = sources.providers or {}

if providers.dadbod then
  print("   ✓ PASS: dadbod source is now in providers!")
  print("   → module: " .. (providers.dadbod.module or "not set"))
  print("   → name: " .. (providers.dadbod.name or "not set"))
  print("   → score_offset: " .. (providers.dadbod.score_offset or "not set"))
else
  print("   ✗ FAIL: dadbod source still not in providers")
  print("   Available providers: " .. vim.inspect(vim.tbl_keys(providers)))
end
print("")

-- Step 4: Check per_filetype
print("4. Checking per_filetype config...")
local per_filetype = sources.per_filetype or {}
if per_filetype.sql then
  print("   ✓ sql filetype sources: " .. vim.inspect(per_filetype.sql))
else
  print("   ⚠ No per_filetype.sql configuration")
end
print("")

-- Step 5: Manually trigger completion to test
print("5. Testing if completion triggers in current buffer...")
local bufnr = vim.api.nvim_get_current_buf()
local ft = vim.bo[bufnr].filetype
print("   Current filetype: " .. ft)

if ft == 'sql' or ft == 'mysql' or ft == 'plsql' then
  print("   ✓ SQL filetype detected")

  -- Try to manually trigger blink completion
  vim.schedule(function()
    -- Trigger completion
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-Space>', true, false, true), 'n', false)
    print("   → Triggered <C-Space> to show completion menu")
  end)
else
  print("   ⚠ Not in SQL buffer")
end

print("\n=== Reload complete ===")
print("\nNext steps:")
print("1. Type in the SQL buffer to trigger completion")
print("2. You should see TEST_DBUI_COMPLETION in the menu")
print("3. If not, check :messages for errors")
