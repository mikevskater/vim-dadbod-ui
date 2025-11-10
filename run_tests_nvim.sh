#!/usr/bin/env bash

# Ensure dependencies are cloned
if [ ! -d "vim-themis" ]; then
  git clone https://github.com/thinca/vim-themis
fi

if [ ! -d "vim-dadbod" ]; then
  git clone https://github.com/tpope/vim-dadbod
fi

if [ ! -d "vim-dotenv" ]; then
  git clone https://github.com/tpope/vim-dotenv
fi

# Configure for Neovim with headless mode
export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless -V1"
export THEMIS_REPORTER="dot"

echo "Running tests with Neovim..."
echo "Vim: $THEMIS_VIM"
echo "Args: $THEMIS_ARGS"
echo ""

# Run tests
./vim-themis/bin/themis

# Capture exit code
EXIT_CODE=$?

echo ""
echo "Tests completed with exit code: $EXIT_CODE"

exit $EXIT_CODE
