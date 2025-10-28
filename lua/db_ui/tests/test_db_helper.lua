-- ============================================================================
-- Database Test Helper Module (Using vim-dadbod-ui Functions)
-- ============================================================================
-- Common utilities for testing against real database connections
-- Uses the plugin's existing infrastructure instead of reinventing the wheel
-- ============================================================================

local M = {}

-- Test database name (consistent across all database types)
M.TEST_DB_NAME = "dbui_test_db"

-- ============================================================================
-- Helper: Execute SQL using vim-dadbod
-- ============================================================================

--- Execute SQL query using vim-dadbod's db#systemlist
---@param url string Database URL
---@param query string SQL query to execute
---@return table|nil result Query results as array of strings
---@return string|nil error Error message if execution failed
function M.execute_sql(url, query)
  -- Step 1: Connect to get connection object
  local success, conn = pcall(vim.fn['db#connect'], url)
  if not success then
    return nil, "Failed to connect: " .. tostring(conn)
  end

  -- Step 2: Get the command dispatch for interactive mode
  local cmd_success, cmd = pcall(vim.fn['db#adapter#dispatch'], conn, 'interactive')
  if not cmd_success then
    return nil, "Failed to get adapter dispatch: " .. tostring(cmd)
  end

  -- Step 3: Execute using db#systemlist (cmd, query)
  local exec_success, result = pcall(function()
    return vim.fn['db#systemlist'](cmd, query)
  end)

  if not exec_success then
    return nil, "Execution failed: " .. tostring(result)
  end

  return result, nil
end

-- ============================================================================
-- Connection Testing
-- ============================================================================

--- Check if a database server is available at localhost
---@param url string Connection URL (e.g., "mysql://localhost")
---@return boolean available True if server is reachable
---@return string|nil error Error message if connection failed
function M.check_server_available(url)
  -- Try to connect using db#connect (same as vim-dadbod-ui uses)
  local success, conn = pcall(vim.fn['db#connect'], url)

  if not success then
    return false, "Connection failed: " .. tostring(conn)
  end

  -- Connection successful - server is available
  return true, nil
end

-- ============================================================================
-- Test Database Creation
-- ============================================================================

--- Create test database (drops existing one if present)
---@param url string Server connection URL
---@param db_name string|nil Database name (defaults to M.TEST_DB_NAME)
---@return boolean success True if database created
---@return string|nil error Error message if creation failed
function M.create_test_database(url, db_name)
  db_name = db_name or M.TEST_DB_NAME
  local parsed = vim.fn['db#url#parse'](url)
  local scheme = parsed.scheme

  -- First drop if exists
  M.drop_test_database(url, db_name)

  -- Then create new
  local create_query = M.get_create_database_query(scheme, db_name)
  if not create_query then
    return false, "Unsupported database type for test DB creation: " .. scheme
  end

  local result, err = M.execute_sql(url, create_query)
  if err then
    return false, "Create database failed: " .. err
  end

  return true, nil
end

--- Get CREATE DATABASE query for specific database type
---@param scheme string Database scheme
---@param db_name string Database name
---@return string|nil query CREATE DATABASE query
function M.get_create_database_query(scheme, db_name)
  local queries = {
    sqlserver = string.format("IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '%s') CREATE DATABASE [%s]", db_name, db_name),
    mysql = string.format("CREATE DATABASE IF NOT EXISTS `%s`", db_name),
    postgresql = string.format("CREATE DATABASE \"%s\"", db_name),
    postgres = string.format("CREATE DATABASE \"%s\"", db_name),
    sqlite = nil, -- SQLite doesn't need CREATE DATABASE
    bigquery = nil, -- BigQuery uses datasets, created differently
    oracle = nil, -- Oracle uses CREATE USER for schemas
  }

  return queries[scheme]
end

-- ============================================================================
-- Test Database Population
-- ============================================================================

--- Populate test database with test objects
---@param url string Database connection URL (including database)
---@param scheme string Database scheme
---@return boolean success True if population succeeded
---@return string|nil error Error message if population failed
function M.populate_test_database(url, scheme)
  -- Get population queries for this database type
  local queries = M.get_population_queries(scheme)
  if not queries then
    return false, "No population queries for scheme: " .. scheme
  end

  -- Execute each query
  for i, query in ipairs(queries) do
    local result, err = M.execute_sql(url, query)
    if err then
      return false, string.format("Population query %d failed: %s\nQuery: %s", i, err, query)
    end
  end

  return true, nil
end

--- Get database population queries (creates tables, views, procedures, functions)
---@param scheme string Database scheme
---@return table|nil queries Array of SQL queries
function M.get_population_queries(scheme)
  if scheme == 'sqlserver' then
    return M.get_sqlserver_population_queries()
  elseif scheme == 'mysql' then
    return M.get_mysql_population_queries()
  elseif scheme == 'postgresql' or scheme == 'postgres' then
    return M.get_postgresql_population_queries()
  elseif scheme == 'sqlite' then
    return M.get_sqlite_population_queries()
  elseif scheme == 'bigquery' then
    return M.get_bigquery_population_queries()
  elseif scheme == 'oracle' then
    return M.get_oracle_population_queries()
  end

  return nil
end

-- ============================================================================
-- SQL Server Population Queries
-- ============================================================================

function M.get_sqlserver_population_queries()
  return {
    -- Create schema
    "IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'test_schema') EXEC('CREATE SCHEMA test_schema')",

    -- Create tables
    [[
    IF OBJECT_ID('test_schema.users', 'U') IS NULL
    CREATE TABLE test_schema.users (
      id INT PRIMARY KEY IDENTITY(1,1),
      username NVARCHAR(50) NOT NULL,
      email NVARCHAR(100),
      created_at DATETIME DEFAULT GETDATE()
    )
    ]],

    [[
    IF OBJECT_ID('test_schema.posts', 'U') IS NULL
    CREATE TABLE test_schema.posts (
      id INT PRIMARY KEY IDENTITY(1,1),
      user_id INT FOREIGN KEY REFERENCES test_schema.users(id),
      title NVARCHAR(200) NOT NULL,
      content NVARCHAR(MAX),
      created_at DATETIME DEFAULT GETDATE()
    )
    ]],

    -- Create view
    [[
    IF OBJECT_ID('test_schema.user_posts_view', 'V') IS NOT NULL
      DROP VIEW test_schema.user_posts_view
    ]],
    [[
    CREATE VIEW test_schema.user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM test_schema.users u
    JOIN test_schema.posts p ON u.id = p.user_id
    ]],

    -- Create stored procedure
    [[
    IF OBJECT_ID('test_schema.get_user_by_id', 'P') IS NOT NULL
      DROP PROCEDURE test_schema.get_user_by_id
    ]],
    [[
    CREATE PROCEDURE test_schema.get_user_by_id
      @user_id INT
    AS
    BEGIN
      SELECT * FROM test_schema.users WHERE id = @user_id
    END
    ]],

    -- Create function
    [[
    IF OBJECT_ID('test_schema.get_user_count', 'FN') IS NOT NULL
      DROP FUNCTION test_schema.get_user_count
    ]],
    [[
    CREATE FUNCTION test_schema.get_user_count()
    RETURNS INT
    AS
    BEGIN
      DECLARE @count INT
      SELECT @count = COUNT(*) FROM test_schema.users
      RETURN @count
    END
    ]],

    -- Insert test data
    "IF NOT EXISTS (SELECT * FROM test_schema.users) INSERT INTO test_schema.users (username, email) VALUES ('testuser1', 'test1@example.com'), ('testuser2', 'test2@example.com')",
  }
end

-- ============================================================================
-- MySQL Population Queries
-- ============================================================================

function M.get_mysql_population_queries()
  return {
    -- Create tables
    [[
    CREATE TABLE IF NOT EXISTS users (
      id INT PRIMARY KEY AUTO_INCREMENT,
      username VARCHAR(50) NOT NULL,
      email VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ]],

    [[
    CREATE TABLE IF NOT EXISTS posts (
      id INT PRIMARY KEY AUTO_INCREMENT,
      user_id INT,
      title VARCHAR(200) NOT NULL,
      content TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
    ]],

    -- Create view
    "DROP VIEW IF EXISTS user_posts_view",
    [[
    CREATE VIEW user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM users u
    JOIN posts p ON u.id = p.user_id
    ]],

    -- Create stored procedure
    "DROP PROCEDURE IF EXISTS get_user_by_id",
    [[
    CREATE PROCEDURE get_user_by_id(IN user_id INT)
    BEGIN
      SELECT * FROM users WHERE id = user_id;
    END
    ]],

    -- Create function
    "DROP FUNCTION IF EXISTS get_user_count",
    [[
    CREATE FUNCTION get_user_count()
    RETURNS INT
    DETERMINISTIC
    BEGIN
      DECLARE user_count INT;
      SELECT COUNT(*) INTO user_count FROM users;
      RETURN user_count;
    END
    ]],

    -- Insert test data
    "INSERT IGNORE INTO users (id, username, email) VALUES (1, 'testuser1', 'test1@example.com'), (2, 'testuser2', 'test2@example.com')",
  }
end

-- ============================================================================
-- PostgreSQL Population Queries
-- ============================================================================

function M.get_postgresql_population_queries()
  return {
    -- Create schema
    "CREATE SCHEMA IF NOT EXISTS test_schema",

    -- Create tables
    [[
    CREATE TABLE IF NOT EXISTS test_schema.users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) NOT NULL,
      email VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ]],

    [[
    CREATE TABLE IF NOT EXISTS test_schema.posts (
      id SERIAL PRIMARY KEY,
      user_id INT REFERENCES test_schema.users(id),
      title VARCHAR(200) NOT NULL,
      content TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ]],

    -- Create view
    "DROP VIEW IF EXISTS test_schema.user_posts_view",
    [[
    CREATE VIEW test_schema.user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM test_schema.users u
    JOIN test_schema.posts p ON u.id = p.user_id
    ]],

    -- Create stored procedure (PostgreSQL 11+)
    "DROP PROCEDURE IF EXISTS test_schema.get_user_by_id",
    [[
    CREATE OR REPLACE PROCEDURE test_schema.get_user_by_id(user_id INT)
    LANGUAGE SQL
    AS $$
      SELECT * FROM test_schema.users WHERE id = user_id;
    $$
    ]],

    -- Create function
    "DROP FUNCTION IF EXISTS test_schema.get_user_count",
    [[
    CREATE OR REPLACE FUNCTION test_schema.get_user_count()
    RETURNS INT AS $$
    BEGIN
      RETURN (SELECT COUNT(*) FROM test_schema.users);
    END;
    $$ LANGUAGE plpgsql
    ]],

    -- Insert test data
    "INSERT INTO test_schema.users (username, email) VALUES ('testuser1', 'test1@example.com'), ('testuser2', 'test2@example.com') ON CONFLICT DO NOTHING",
  }
end

-- ============================================================================
-- SQLite Population Queries
-- ============================================================================

function M.get_sqlite_population_queries()
  return {
    -- Create tables
    [[
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      email TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ]],

    [[
    CREATE TABLE IF NOT EXISTS posts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      title TEXT NOT NULL,
      content TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
    ]],

    -- Create view
    "DROP VIEW IF EXISTS user_posts_view",
    [[
    CREATE VIEW user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM users u
    JOIN posts p ON u.id = p.user_id
    ]],

    -- Insert test data
    "INSERT OR IGNORE INTO users (id, username, email) VALUES (1, 'testuser1', 'test1@example.com'), (2, 'testuser2', 'test2@example.com')",
  }
end

-- ============================================================================
-- BigQuery Population Queries
-- ============================================================================

function M.get_bigquery_population_queries()
  return {
    -- Create tables
    [[
    CREATE TABLE IF NOT EXISTS users (
      id INT64,
      username STRING,
      email STRING,
      created_at TIMESTAMP
    )
    ]],

    [[
    CREATE TABLE IF NOT EXISTS posts (
      id INT64,
      user_id INT64,
      title STRING,
      content STRING,
      created_at TIMESTAMP
    )
    ]],

    -- Create view
    [[
    CREATE OR REPLACE VIEW user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM users u
    JOIN posts p ON u.id = p.user_id
    ]],
  }
end

-- ============================================================================
-- Oracle Population Queries
-- ============================================================================

function M.get_oracle_population_queries()
  return {
    -- Create tables
    [[
    BEGIN
      EXECUTE IMMEDIATE 'CREATE TABLE users (
        id NUMBER PRIMARY KEY,
        username VARCHAR2(50) NOT NULL,
        email VARCHAR2(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;
    END;
    ]],

    -- Create sequence
    [[
    BEGIN
      EXECUTE IMMEDIATE 'CREATE SEQUENCE users_seq START WITH 1 INCREMENT BY 1';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;
    END;
    ]],

    [[
    BEGIN
      EXECUTE IMMEDIATE 'CREATE TABLE posts (
        id NUMBER PRIMARY KEY,
        user_id NUMBER REFERENCES users(id),
        title VARCHAR2(200) NOT NULL,
        content CLOB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;
    END;
    ]],

    -- Create view
    [[
    CREATE OR REPLACE VIEW user_posts_view AS
    SELECT u.username, p.title, p.created_at
    FROM users u
    JOIN posts p ON u.id = p.user_id
    ]],

    -- Create procedure
    [[
    CREATE OR REPLACE PROCEDURE get_user_by_id(p_user_id IN NUMBER) AS
    BEGIN
      FOR rec IN (SELECT * FROM users WHERE id = p_user_id) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.username);
      END LOOP;
    END;
    ]],

    -- Create function
    [[
    CREATE OR REPLACE FUNCTION get_user_count RETURN NUMBER AS
      v_count NUMBER;
    BEGIN
      SELECT COUNT(*) INTO v_count FROM users;
      RETURN v_count;
    END;
    ]],
  }
end

-- ============================================================================
-- Test Database Cleanup
-- ============================================================================

--- Drop test database
---@param url string Server connection URL
---@param db_name string|nil Database name (defaults to M.TEST_DB_NAME)
---@return boolean success True if database dropped or didn't exist
---@return string|nil error Error message if drop failed
function M.drop_test_database(url, db_name)
  db_name = db_name or M.TEST_DB_NAME
  local parsed = vim.fn['db#url#parse'](url)
  local scheme = parsed.scheme

  local drop_query = M.get_drop_database_query(scheme, db_name)
  if not drop_query then
    -- Database type doesn't support DROP DATABASE (e.g., SQLite file-based)
    return true, nil
  end

  -- Execute drop (don't fail if database doesn't exist)
  M.execute_sql(url, drop_query)
  return true, nil
end

--- Get DROP DATABASE query for specific database type
---@param scheme string Database scheme
---@param db_name string Database name
---@return string|nil query DROP DATABASE query
function M.get_drop_database_query(scheme, db_name)
  local queries = {
    sqlserver = string.format("IF EXISTS (SELECT * FROM sys.databases WHERE name = '%s') DROP DATABASE [%s]", db_name, db_name),
    mysql = string.format("DROP DATABASE IF EXISTS `%s`", db_name),
    postgresql = string.format("DROP DATABASE IF EXISTS \"%s\"", db_name),
    postgres = string.format("DROP DATABASE IF EXISTS \"%s\"", db_name),
    sqlite = nil, -- SQLite uses file deletion
    bigquery = nil, -- BigQuery uses dataset deletion
    oracle = nil, -- Oracle uses DROP USER
  }

  return queries[scheme]
end

-- ============================================================================
-- URL Utilities
-- ============================================================================

--- Get test database URL from server URL
---@param server_url string Server connection URL (e.g., "mysql://localhost")
---@param db_name string|nil Database name (defaults to M.TEST_DB_NAME)
---@return string db_url Database connection URL
function M.get_test_db_url(server_url, db_name)
  db_name = db_name or M.TEST_DB_NAME
  local parsed = vim.fn['db#url#parse'](server_url)

  -- Add database to path
  if parsed.scheme == 'sqlite' then
    -- SQLite uses file path
    return string.format("sqlite:///%s.db", db_name)
  else
    -- Other databases use URL path
    local base_url = server_url:gsub("/$", "") -- Remove trailing slash
    return string.format("%s/%s", base_url, db_name)
  end
end

return M
