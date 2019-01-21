#!/bin/bash

set -x

# use ccache
export PATH="/usr/local/opt/ccache/libexec:$PATH"

# fetch V8 if necessary
if [ ! -d "./v8build/v8" ]; then
  cd ./v8build

  # get the Google depot tools
  git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
  export PATH=${PATH}:$(pwd)/depot_tools

  # obtain proper V8 version
  gclient
  fetch v8 && cd ./v8
  git checkout 6.8.290

  # disable some warnings
  CONFIG_DEFAULT_WARNINGS_LINE=$(grep --line-number "^config(\"default\_warnings\") {$" build/config/compiler/BUILD.gn | cut -f1 -d:)
  IS_CLANG_LINE=$(tail -n +${CONFIG_DEFAULT_WARNINGS_LINE} build/config/compiler/BUILD.gn | grep --line-number "^  if (is\_clang) {$" | head -n 1 | cut -f1 -d:)
  INSERT_CFLAGS_LINE=$((CONFIG_DEFAULT_WARNINGS_LINE + IS_CLANG_LINE + 1))
  ex -s -c "${INSERT_CFLAGS_LINE}i|      \"-Wno-null-pointer-arithmetic\"," -c x build/config/compiler/BUILD.gn
  ex -s -c "${INSERT_CFLAGS_LINE}i|      \"-Wno-defaulted-function-deleted\"," -c x build/config/compiler/BUILD.gn

  # the trace event repository is checked out at master, which does not compile currently
  # so use the version that was most likely used for 6.8.290
  cd ./base/trace_event/common
  git checkout 211b3ed9d0481b4caddbee1322321b86a483ca1f
  cd ../../../

  # configure release
  find . -name BUILD.gn -exec sed -i bak '/exe_and_shlib_deps/d' {} \;
  ./tools/dev/v8gen.py x64.release
  export RELEASE=out.gn/x64.release

  # from the chromium docs
  export CCACHE_CPP2=yes
  export CCACHE_SLOPPINESS=time_macros
  export PATH="$(pwd)/third_party/llvm-build/Release+Asserts/bin:${PATH}"

  # generate release info
  gn gen ${RELEASE} \
    --args='cc_wrapper="ccache" is_component_build=false is_debug=false target_cpu="x64" use_custom_libcxx=false use_custom_libcxx_for_host=false v8_static_library=true'
fi
