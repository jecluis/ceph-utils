#!/bin/bash

usage() {
  cat <<EOF
usage: $0 [OPTIONS]

OPTIONS:
  -c | --config FILE  Use specified config file.
  --no-clang          Build using g++ instead of clang
  -h | --help         Show this message.

ENV VARS:
  S3GW_CCACHE_DIR   Specifies the location of ccache.
EOF
}

CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-"Debug"}

WITH_TESTS=${WITH_TESTS:-"OFF"}
RUN_TESTS=${RUN_TESTS:-"OFF"}

ENABLE_GIT_VERSION=${ENABLE_GIT_VERSION:-"ON"}

WITH_RADOSGW_DBSTORE=${WITH_RADOSGW_DBSTORE:-"OFF"}
ALLOCATOR=${ALLOCATOR:-"tcmalloc"}
WITH_SYSTEM_BOOST=${WITH_SYSTEM_BOOST:-"OFF"}
WITH_SYSTEM_GTEST=${WITH_SYSTEM_GTEST:-"ON"}
WITH_JAEGER=${WITH_JAEGER:-"OFF"}

WITH_ASAN=${WITH_ASAN:-"OFF"}
WITH_ASAN_LEAK=${WITH_ASAN_LEAK:-"OFF"}
WITH_TSAN=${WITH_TSAN:-"OFF"}
WITH_UBSAN=${WITH_UBSAN:-"OFF"}


CC=${CC:-"/usr/bin/clang"}
CXX=${CXX:-"/usr/bin/clang++"}

no_clang=0
config_file=

while [[ $# -gt 0 ]]; do

  case $1 in
    -c|--config)
      config_file="${2}"
      shift 1
      ;;
    --no-clang)
      no_clang=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '${1}'" >/dev/stderr
      exit 1
      ;;
  esac
  shift 1

done

if [[ -n "${config_file}" ]]; then
  if [[ -e "${config_file}" ]]; then
    source ${config_file}
  else
    echo "error: config file at '${config_file}' does not exist!" >/dev/stderr
    exit 1
  fi
fi

if [[ $no_clang -eq 1 ]]; then
  CC="gcc-13"
  CXX="g++-13"
fi

if [[ -z "${S3GW_CCACHE_DIR}" ]]; then
  echo "error: S3GW_CCACHE_DIR not set!" >/dev/stderr
  exit 1
fi

export CCACHE_DIR=${S3GW_CCACHE_DIR}
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
  "-DWITH_SYSTEM_GTEST=${WITH_SYSTEM_GTEST}"
  "-DWITH_ASAN=${WITH_ASAN}"
  "-DWITH_ASAN_LEAK=${WITH_ASAN_LEAK}"
  "-DWITH_TSAN=${WITH_TSAN}"
  "-DWITH_UBSAN=${WITH_UBSAN}"
#  "-DWITH_MGR=OFF"
)

echo "----- Prepare build -----"
echo "CCACHE DIR: ${S3GW_CCACHE_DIR}"
echo
for var in ${ARGS[@]} ; do
  echo ${var}
done
echo "--------------------------"
echo

./do_cmake.sh ${ARGS[@]} || exit 1
