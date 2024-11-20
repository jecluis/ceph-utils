#!/bin/bash

ccache_dir=${S3GW_CCACHE_DIR:-}
nproc=${S3GW_NPROC:-20}
debug=${S3GW_DEBUG:-10}
with_gdb=${S3GW_WITH_GDB:-0}
no_build=${S3GW_NO_BUILD:-0}
build_only=${S3GW_BUILD_ONLY:-0}

d=${PWD##*/}
backend=${BACKEND:-"sfs"}

# this needs to be specifically enabled, ignore config env.
#
with_tests=0

# list of unit tests to run if enabled
#
unit_tests=()

usage() {
  cat <<EOF
usage: $0 [options]

options:
  -b | --build-only     Only build, don't run.
  -n | --no-build       Don't build, only run.
  -c | --ccache DIR     Specify ccache directory.
  -p | --proc VALUE     Use VALUE number of processes.
  -d | --debug VALUE    Set rgw debug to VALUE.
  -g | --with-gdb       Run with gdb.
  -t | --with-tests     Build and/or run unit tests.
  -h | --help           Show this message.

env:
  ccache dir:  ${ccache_dir}
       nproc:  ${nproc}
       debug:  ${debug}
EOF
}

while [[ $# -gt 0 ]]; do

  case $1 in
    -b|--build-only) build_only=1 ;;
    -c|--ccache)
      ccache_dir=$2
      shift 1
      ;;
    -p|--proc)
      nproc=$2
      shift 1
      ;;
    -d|--debug)
      debug=$2
      shift 1
      ;;
    -g|--with-gdb)
      with_gdb=1
      ;;
    -n|--no-build)
      no_build=1
      ;;
    -t|--with-tests)
      with_tests=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option '$1'" >/dev/stderr
      exit 1
      ;;
  esac

  shift 1

done

[[ -z "${ccache_dir}" ]] && \
  echo "missing ccache dir" >/dev/stderr && exit 1

[[ ! -d "${ccache_dir}" ]] && \
  echo "ccache dir at '${ccache_dir}' does not exist" >/dev/stderr && exit 1

if [[ "${d}" != "build" ]]; then
	[[ ! -d "build" ]] && echo "can't find build directory" && exit 1
	pushd build >/dev/null || exit 1
fi

if [[ $with_tests -eq 1 ]]; then
  # discover tests from ctest tags, selecting all which have the s3gw tag.
  #
  mapfile -t \
    unit_tests <<< "$(ctest -N -L s3gw | grep 'Test #' | awk '{print $3}')"

  if [[ ${#unit_tests} -eq 0 ]]; then
    echo "error: attempted to find unit tests, but none were found!"
    exit 1
  fi
fi

if [[ $no_build -eq 0 ]]; then
  CCACHE_DIR=${ccache_dir} ninja -j ${nproc} bin/radosgw || \
	exit 1

  if [[ $with_tests -eq 1 ]]; then
    # build unit tests
    #
    echo "Building unit tests..."
    
    if [[ ${#unit_tests} -eq 0 ]]; then
      echo "error: attempting to build unit tests, but none were found!"
      exit 1
    fi
    CCACHE_DIR=${ccache_dir} ninja -j ${nproc} "${unit_tests[@]}" || exit 1
  fi
fi

args="--rgw-sfs-data-path $(pwd)/dev/rgw.foo"
if [[ "${backend}" == "dbstore" ]]; then
	args="--rgw-dbstore-data-path $(pwd)/dev/rgw.foo"
fi

maybe_gdb() {
	if [[ ${with_gdb} -eq 1 ]]; then
		gdb --args $*
	else
		$*
	fi
}


[[ ! -d "$(pwd)/dev/rgw.foo" ]] && mkdir -p $(pwd)/dev/rgw.foo

if [[ $build_only -eq 1 ]]; then
  echo "not running, build-only requested!"
  exit 0
fi

# running tests instead of radosgw.
#
if [[ $with_tests -eq 1 ]]; then

  if [[ ${#unit_tests} -eq 0 ]]; then
    echo "error: attempting to run unit tests, but none were found!"
    exit 1
  fi

  ret_code=0
  for unit_test in ${unit_tests[@]} ; do
    echo "Running unit test at ${unit_test}"
    bin/${unit_test}
    tmp_ret_code=$!
    [[ $tmp_ret_code -ne 0 ]] && ret_code=${tmp_ret_code}
  done

  exit ${ret_code}
fi

maybe_gdb bin/radosgw \
	--rgw-backend-store=${backend} \
	${args} \
	-i foo \
	--debug-rgw ${debug} \
	--no-mon-config \
	--rgw-data $(pwd)/dev/rgw.foo \
	--run-dir $(pwd)/dev/rgw.foo \
	--debug-lockdep 20 \
  --rgw-lc-debug-interval 60 \
  --rgw_sfs_sqlite_profile true \
	-d

