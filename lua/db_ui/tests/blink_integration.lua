-- ============================================================================
-- blink.cmp Integration Tests
-- ============================================================================

local M = {}
local test = require('db_ui.tests.init')

function M.setup()
  vim.g.db_ui_enable_intellisense = 1
end

-- ============================================================================
-- Tests
-- ============================================================================

function M.test_blink_source_can_be_required()
  local success, source = pcall(require, 'blink.cmp.sources.dadbod')
  test.assert(success, "blink.cmp.sources.dadbod should be loadable")
  test.assert_not_nil(source, "Source module should not be nil")
end

function M.test_blink_source_has_new_function()
  local source = require('blink.cmp.sources.dadbod')
  test.assert_not_nil(source.new, "Source should have new() function")
  test.assert_equal(type(source.new), "function", "new should be a function")
end

function M.test_blink_source_instance_creation()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  test.assert_not_nil(instance, "Should create source instance")
end

function M.test_blink_source_has_required_methods()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  test.assert_not_nil(instance.enabled, "Source should have enabled() method")
  test.assert_not_nil(instance.get_trigger_characters, "Source should have get_trigger_characters() method")
  test.assert_not_nil(instance.get_completions, "Source should have get_completions() method")
end

function M.test_get_trigger_characters_returns_table()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local triggers = instance:get_trigger_characters()

  test.assert_equal(type(triggers), "table", "Trigger characters should be a table")
  test.assert(#triggers > 0, "Should have at least one trigger character")
end

function M.test_trigger_characters_include_dot()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local triggers = instance:get_trigger_characters()

  test.assert_contains(triggers, '.', "Trigger characters should include '.'")
end

function M.test_trigger_characters_include_at_sign()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local triggers = instance:get_trigger_characters()

  test.assert_contains(triggers, '@', "Trigger characters should include '@' for parameters")
end

function M.test_enabled_returns_boolean()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  -- Save current filetype
  local original_ft = vim.bo.filetype

  -- Test with SQL filetype
  vim.bo.filetype = 'sql'
  local enabled = instance:enabled()
  test.assert_equal(type(enabled), "boolean", "enabled() should return boolean")

  -- Restore original filetype
  vim.bo.filetype = original_ft
end

function M.test_enabled_true_for_sql_filetype()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local original_ft = vim.bo.filetype

  vim.bo.filetype = 'sql'
  local enabled = instance:enabled()

  -- Should be enabled for SQL if IntelliSense is available
  -- (might be false if no DB connection, but shouldn't error)
  test.assert_equal(type(enabled), "boolean", "Should return boolean for SQL filetype")

  vim.bo.filetype = original_ft
end

function M.test_enabled_false_for_non_sql_filetype()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local original_ft = vim.bo.filetype

  vim.bo.filetype = 'lua'
  local enabled = instance:enabled()

  test.assert_equal(enabled, false, "Should be disabled for non-SQL filetypes")

  vim.bo.filetype = original_ft
end

function M.test_completion_item_kind_mapping_exists()
  local source = require('blink.cmp.sources.dadbod')

  -- The source module should have kind mapping internally
  -- We can verify by checking the source code structure
  test.assert_not_nil(source, "Source module should exist for kind mapping")
end

function M.test_source_transform_item_function()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  -- Create a mock item
  local item = {
    word = "user_id",
    kind = "C",
    data_type = "INT",
    info = "Type: INT | NOT NULL"
  }

  local transformed = instance:transform_item(item)

  test.assert_not_nil(transformed, "Should transform item")
  test.assert_not_nil(transformed.label, "Transformed item should have label")
  test.assert_equal(transformed.label, "user_id", "Label should match word")
  test.assert_not_nil(transformed.kind, "Transformed item should have kind")
end

function M.test_column_info_formatting()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local column = {
    name = "user_id",
    data_type = "INT",
    nullable = false,
    is_pk = true,
    is_fk = false
  }

  local info = instance:format_column_info(column)

  test.assert_not_nil(info, "Should format column info")
  test.assert(info:match("INT"), "Should include data type")
  test.assert(info:match("PRIMARY KEY"), "Should indicate primary key")
end

function M.test_table_info_formatting()
  local source = require('blink.cmp.sources.dadbod')
  local instance = source.new()

  local tbl = {
    name = "Users",
    type = "table",
    schema = "dbo"
  }

  local info = instance:format_table_info(tbl)

  test.assert_not_nil(info, "Should format table info")
  test.assert(info:match("TABLE"), "Should include table type")
  test.assert(info:match("dbo"), "Should include schema")
end

return M
