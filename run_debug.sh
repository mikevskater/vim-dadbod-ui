#!/usr/bin/env bash

set -x  # Print commands as they execute

echo "=== Starting test run ==="
echo "Current directory: $(pwd)"
echo "Nvim location: $(which nvim)"
echo "Nvim version:"
nvim --version | head -3
echo ""

# Check dependencies
echo "=== Checking dependencies ==="
if [ ! -d "vim-themis" ]; then
  echo "vim-themis not found, cloning..."
  git clone https://github.com/thinca/vim-themis
else
  echo "vim-themis: OK"
fi

if [ ! -d "vim-dadbod" ]; then
  echo "vim-dadbod not found, cloning..."
  git clone https://github.com/tpope/vim-dadbod
else
  echo "vim-dadbod: OK"
fi

if [ ! -d "vim-dotenv" ]; then
  echo "vim-dotenv not found, cloning..."
  git clone https://github.com/tpope/vim-dotenv
else
  echo "vim-dotenv: OK"
fi

echo ""
echo "=== Running tests ==="
export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless"

echo "THEMIS_VIM=$THEMIS_VIM"
echo "THEMIS_ARGS=$THEMIS_ARGS"
echo ""

# Run just one test file first to see if it works
echo "Testing with single file first..."
./vim-themis/bin/themis test/test-completion-cache.vim

EXIT_CODE=$?
echo ""
echo "=== Test completed with exit code: $EXIT_CODE ==="
