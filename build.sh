#!/bin/bash

set -x

ARGS="$@"

echo "Building ${ARGS}"

# use ccache
export PATH="/usr/local/opt/ccache/libexec:$PATH"

# get the Google depot tools
mkdir v8build && cd ./v8build
git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=${PATH}:$(pwd)/depot_tools

# obtain proper V8 version
gclient
fetch v8 && cd ./v8
git checkout 6.8.290

# configure release
find . -name BUILD.gn -exec sed -i bak '/exe_and_shlib_deps/d' {} \;
./tools/dev/v8gen.py x64.release
export RELEASE=out.gn/x64.release
echo "is_component_build = false" >> ${RELEASE}/args.gn
echo "v8_static_library = true" >> ${RELEASE}/args.gn
echo "use_custom_libcxx = false" >> ${RELEASE}/args.gn
echo "use_custom_libcxx_for_host = false" >> ${RELEASE}/args.gn
echo "cc_wrapper = \"ccache\"" >> ${RELEASE}/args.gn
export CONFIG_DEFAULT_WARNINGS_LINE=$(grep --line-number "^config(\"default\_warnings\") {$" build/config/compiler/BUILD.gn | cut -f1 -d:)
export IS_CLANG_LINE=$(tail -n +${CONFIG_DEFAULT_WARNINGS_LINE} build/config/compiler/BUILD.gn | grep --line-number "^  if (is\_clang) {$" | head -n 1 | cut -f1 -d:)
export INSERT_CFLAGS_LINE=$((CONFIG_DEFAULT_WARNINGS_LINE + IS_CLANG_LINE + 1))
ex -s -c "${INSERT_CFLAGS_LINE}i|      \"-Wno-null-pointer-arithmetic\"," -c x build/config/compiler/BUILD.gn
ex -s -c "${INSERT_CFLAGS_LINE}i|      \"-Wno-defaulted-function-deleted\"," -c x build/config/compiler/BUILD.gn

# the trace event repository is checked out at master, which does not compile currently
# so use the version that was most likely used for 6.8.290
cd ./base/trace_event/common
git checkout 211b3ed9d0481b4caddbee1322321b86a483ca1f
cd ../../../

# from the chromium docs
export CCACHE_CPP2=yes
export CCACHE_SLOPPINESS=time_macros
export PATH="$(pwd)/third_party/llvm-build/Release+Asserts/bin:${PATH}"

# finally build
gn gen ${RELEASE}
ninja -C ${RELEASE} ${ARGS}
