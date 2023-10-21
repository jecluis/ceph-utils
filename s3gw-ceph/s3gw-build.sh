#!/bin/bash

# real location of this script
#
real_path=$(realpath $0)
real_dir=$(dirname ${real_path})

# if a symlink, location from which the symlink is invoked; otherwise, the
# real location of this script.
#
base_dir=$(realpath $(dirname $0))

config_file="${base_dir}/.s3gw-build.cfg"

# pre-flight checks: are we able to find the tools we need?
#
tool_do_cmake="${real_dir}/do_s3gw_cmake_v2.sh"
tool_run_sfs="${real_dir}/run-sfs.sh"

for tool in ${tool_do_cmake} ${tool_run_sfs} ; do
  if [[ ! -e "${tool}" ]]; then
    echo "error: couldn't find '${tool}' !" >/dev/stderr
    exit 1
  elif [[ ! -x "${tool}" ]]; then
    echo "error: tool '${tool}' not executable!" >/dev/stderr
    exit 1
  fi
done

# pre-flight checks: are we in a 'ceph.git' directory?
#
if [[ ! -e "src/ceph_ver.c" ]]; then
  echo "error: must be run on a ceph repository's root!" >/dev/stderr
  exit 1

elif [[ ! -d ".git" ]]; then
  echo "error: not a ceph git repository!" >/dev/stderr
  exit 1
fi

# options
#
run_with_build=0    # build before running
force=0             # force operation (for prepare, blow existing build dir)


usage() {
  cat <<EOF >/dev/stderr
usage: $0 COMMAND [OPTIONS] [-- [args...]]

COMMANDS:
  gen-config  Generate base config.
  gen-cmds    Generate compile commands file for clang.
  gen-dev     Prepare development environment.

  prepare     Prepare to build.
  build       Build.
  run         Run.

OPTIONS:
  -c | --config FILE  The config file (default: ${config_file}).
  -h | --help         Shows this message.

 for 'prepare':
  -f | --force        Forces preparing the build, removing existing build
                      if necessary.

 for 'run':
  -b | --build        Builds before running.

For any of the provided commands, running with '-- --help' will provide
additional information on available options.

EOF
}

# keep extra arguments, to pass to specific commands
#
extra_args=

gen_config() {

  if [[ -e "${config_file}" ]]; then
    echo "error: config file at ${config_file} already exists." >/dev/stderr
    echo "please remove existing config file before generating a new one" \
      >/dev/stderr
    exit 1
  fi

  echo "generating base config..."
  cat <<EOF >${config_file}
export S3GW_CCACHE_DIR=MY_CCACHE_DIR
export S3GW_NPROC=$(($(nproc) - 2))

# additional env variables for preparing build
#
export CMAKE_BUILD_TYPE="Debug"
export WITH_TESTS="OFF"
export RUN_TESTS="OFF"
export ENABLE_GIT_VERSION="ON"

EOF

  echo "configuration written to ${config_file}"
  echo "please edit it to match your requirements."
  exit 0
}

gen_clang_commands() {

  # pre-flight checks: build directory must exist
  #
  if [[ ! -d "./build" ]]; then
    echo "error: build directory not found!" >/dev/stderr
    echo "must run the 'prepare' stage first." >/dev/stderr
    exit 1
  fi

  pushd ./build >/dev/null
  ninja -t compdb > ../compile_commands.json || exit 1
  popd >/dev/null

  echo "compile commands available at $(pwd)/compile_commands.json"
}

gen_dev_env() {
  cat <<EOF >.clangd
CompileFlags:
  Add:
    - -std=c++20
    - -Wall
    - -I$(pwd)/src
    - -I$(pwd)/src/rgw
    - -I$(pwd)/src/rgw/driver/rados
    - -I$(pwd)/src/rgw/driver/sfs
    - -I$(pwd)/src/test
    - -I$(pwd)/build/include
    - -I$(pwd)/build/boost/include
    - -I$(pwd)/src/s3select/rapidjson/include
    - -I$(pwd)/src/spawn/include
    - -I$(pwd)/src/jaegertracing/opentelemetry-cpp/api/include
    - -I/usr/include/lua5.4


EOF

  echo "clangd config available at $(pwd)/.clangd"
}

prepare() {
  # pre-flight checks: does build dir exist?
  #
  if [[ -d "./build" ]]; then
    if [[ $force -eq 1 ]]; then
      echo "build directory exists, blowing it away!"
      rm -fr ./build || exit 1
    else
      echo "error: build directory already exists, abort!" >/dev/stderr
      exit 1
    fi
  fi

  ${tool_do_cmake} ${extra_args} || exit 1
}

build() {

  # pre-flight checks: does the build directory exist?
  #
  if [[ ! -d "./build" ]]; then
    echo "error: build directory doesn't exist!" >/dev/stderr
    echo "run the 'prepare' stage first." >/dev/stderr
    exit 1
  fi

  ${tool_run_sfs} --build-only ${extra_args} || exit 1
}

run() {

  # pre-flight checks: does the build directory exist?
  #
  if [[ ! -d "./build" ]]; then
    echo "error: build directory doesn't exist!" >/dev/stderr
    echo "run the 'prepare' stage first." >/dev/stderr
    exit 1
  fi

  if [[ $run_with_build -eq 1 ]]; then
    # build first
    build || exit 1
  fi

  # pre-flight checks: does the radosgw binary exist?
  #
  if [[ ! -e "./build/bin/radosgw" ]]; then
    echo "error: radosgw binary not available!" >/dev/stderr
    echo "run the 'build' stage first." >/dev/stderr
    exit 1
  fi

  ${tool_run_sfs} --no-build ${extra_args} || exit 1
}


if [[ $# -lt 1 ]]; then
  echo "error: missing command" >/dev/stderr
  usage
  exit 1
fi

cmd="${1}"
shift 1

while [[ $# -gt 0 ]]; do

  case $1 in
    -c|--config)
      config_file="${2}"
      shift 1
      ;;
    -b|--build)
      run_with_build=1
      ;;
    -f|--force)
      force=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift 1
      extra_args="$*"
      break
      ;;
    *)
      echo "error: unknown option: ${1}" >/dev/stderr
      exit 1
      ;;
  esac
  shift 1

done

if [[ -z "${config_file}" ]]; then
  echo "error: must specify a configuration file!" >/dev/stderr
  exit 1
fi

# config must be generated before handling the remaining operations, because we
# do multiple config related checks as we go forward.
#
case $cmd in
  gen-config)
    gen_config
    exit 0
    ;;
esac


if [[ ! -e "${config_file}" ]]; then
  echo "error: config file at ${config_file} does not exist!" >/dev/stderr
  exit 1
fi

source ${config_file}

# validate config
#
ccache_dir=${S3GW_CCACHE_DIR:-}
nproc=${S3GW_NPROC:-}

if [[ -z "${ccache_dir}" ]]; then
  echo "error: S3GW_CCACHE_DIR not set!" >/dev/stderr
  exit 1
elif [[ "${ccache_dir}" == "MY_CCACHE_DIR" ]]; then
  echo "error: S3GW_CCACHE_DIR has default, dummy value!" >/dev/stderr
  exit 1
elif [[ -z "${nproc}" ]]; then
  echo "error: S3GW_NPROC not set!" >/dev/stderr
  exit 1
fi

case ${cmd} in
  gen-cmds)
    gen_clang_commands
    exit 0
    ;;
  gen-dev)
    gen_dev_env
    exit 0
    ;;
  prepare)
    prepare
    exit 0
    ;;
  build)
    build
    exit 0
    ;;
  run)
    run
    exit 0
    ;;
  *)
    echo "error: unknown command: ${cmd}" >/dev/stderr
    exit 1
    ;;

esac


