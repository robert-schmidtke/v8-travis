#!/bin/bash

set -x

ARGS="$@"

echo "Building ${ARGS}"

# use ccache
export PATH="/usr/local/opt/ccache/libexec:$PATH"

cd ./v8build

# export necessary variables nonetheless
export PATH=${PATH}:$(pwd)/depot_tools
export RELEASE=out.gn/x64.release

cd ./v8

# from the chromium docs
export CCACHE_CPP2=yes
export CCACHE_SLOPPINESS=time_macros
export PATH="$(pwd)/third_party/llvm-build/Release+Asserts/bin:${PATH}"

# finally build
ninja -C ${RELEASE} ${ARGS}
