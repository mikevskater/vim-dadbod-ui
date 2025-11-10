#!/usr/bin/env bash

if [ ! -d "vim-themis" ]; then
  git clone https://github.com/thinca/vim-themis
fi

if [ ! -d "vim-dadbod" ]; then
  git clone https://github.com/tpope/vim-dadbod
fi

if [ ! -d "vim-dotenv" ]; then
  git clone https://github.com/tpope/vim-dotenv
fi

# Use Neovim for tests (required for Lua/Phase 4 tests)
export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless"

./vim-themis/bin/themis
