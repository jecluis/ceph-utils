#!/bin/bash

usage() {
  cat <<EOF
usage: $0 [--clang]
EOF
}

CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-"Debug"}

WITH_TESTS=${WITH_TESTS:-"OFF"}
RUN_TESTS=${RUN_TESTS:-"OFF"}

ENABLE_GIT_VERSION=${ENABLE_GIT_VERSION:-"ON"}

WITH_RADOSGW_DBSTORE=${WITH_RADOSGW_DBSTORE:-"OFF"}
ALLOCATOR=${ALLOCATOR:-"tcmalloc"}
WITH_SYSTEM_BOOST=${WITH_SYSTEM_BOOST:-"OFF"}
WITH_JAEGER=${WITH_JAEGER:-"OFF"}

WITH_ASAN=${WITH_ASAN:-"OFF"}
WITH_ASAN_LEAK=${WITH_ASAN_LEAK:-"OFF"}
WITH_TSAN=${WITH_TSAN:-"OFF"}
WITH_UBSAN=${WITH_UBSAN:-"OFF"}


CC=${CC:-"gcc-13"}
CXX=${CXX:-"g++-13"}

if [[ $# -gt 0 && "${1}" == "--clang" ]]; then
  CC="/usr/bin/clang"
  CXX="/usr/bin/clang++"
fi

export CCACHE_DIR=/home/joao/aquarist-labs/.s3gw-ceph-ccache
ARGS=(
  "-GNinja"
  "-DCMAKE_C_COMPILER=${CC}"
  "-DCMAKE_CXX_COMPILER=${CXX}"
  "-DENABLE_GIT_VERSION=${ENABLE_GIT_VERSION}"
  "-DWITH_PYTHON3=3.11"
  "-DWITH_CCACHE=ON"
  "-DWITH_TESTS=${WITH_TESTS}"
  "-DALLOCATOR=${ALLOCATOR}"
  "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=YES"
  "-DWITH_JAEGER=${WITH_JAEGER}"
  "-DWITH_LTTNG=OFF"
  "-DWITH_MANPAGE=OFF"
  "-DWITH_OPENLDAP=OFF"
  "-DWITH_RADOSGW_AMQP_ENDPOINT=OFF"
  "-DWITH_RADOSGW_DBSTORE=${WITH_RADOSGW_DBSTORE}"
  "-DWITH_RADOSGW_KAFKA_ENDPOINT=OFF"
  "-DWITH_RADOSGW_LUA_PACKAGES=OFF"
  "-DWITH_RADOSGW_MOTR=OFF"
  "-DWITH_RADOSGW_SELECT_PARQUET=OFF"
  "-DWITH_RDMA=OFF"
  "-DWITH_SYSTEM_BOOST=${WITH_SYSTEM_BOOST}"
  "-DWITH_ASAN=${WITH_ASAN}"
  "-DWITH_ASAN_LEAK=${WITH_ASAN_LEAK}"
  "-DWITH_TSAN=${WITH_TSAN}"
  "-DWITH_UBSAN=${WITH_UBSAN}"
#  "-DWITH_MGR=OFF"
)

./do_cmake.sh ${ARGS[@]} || exit 1