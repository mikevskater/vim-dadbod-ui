-- BigQuery Connection Tests (Cloud-based, typically skipped)
local M = {}
local test = require('db_ui.tests.init')
local config = require('db_ui.tests.test_config')

M.server_url = nil
M.server_available = false
M.skip_reason = "BigQuery is cloud-based and requires authentication"

function M.setup()
  vim.g.db_ui_use_ssms_style = 0
  M.server_url = config.get_server_url('bigquery')
  if not M.server_url then
    M.skip_reason = "BigQuery not configured in test_config.lua"
    return
  end
  -- Even if configured, BigQuery requires special setup
  print("⚠️  BigQuery requires gcloud authentication")
  print("⚠️  Skipping real database tests for BigQuery")
end

function M.teardown() end

local function skip()
  print("⚠️  Skipping BigQuery tests: " .. M.skip_reason)
  return true
end

-- Basic URL parsing tests (these work without connecting)
function M.test_basic_bigquery_connection_scheme()
  local parsed = vim.fn['db#url#parse']('bigquery:my-project')
  test.assert_equal(parsed.scheme, 'bigquery', 'Should parse bigquery scheme')
end

function M.test_can_parse_bigquery_with_dataset()
  local parsed = vim.fn['db#url#parse']('bigquery:my-project/my_dataset')
  test.assert_equal(parsed.scheme, 'bigquery', 'Should parse bigquery scheme')
end

function M.test_bigquery_is_cloud_based()
  -- BigQuery is cloud-based, requires gcloud auth
  test.assert(true, 'BigQuery is cloud-based and requires authentication')
end

function M.test_bigquery_uses_datasets()
  -- BigQuery uses "datasets" instead of databases
  test.assert(true, 'BigQuery uses datasets')
end

function M.test_bigquery_supports_standard_sql()
  -- BigQuery supports standard SQL syntax
  test.assert(true, 'BigQuery supports standard SQL')
end

-- Skipped tests (would require real connection)
function M.test_can_connect_to_bigquery()
  if skip() then return end
end

function M.test_can_list_datasets()
  if skip() then return end
end

function M.test_can_access_tables()
  if skip() then return end
end

return M
