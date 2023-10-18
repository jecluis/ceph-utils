#!/bin/bash

DEBUG=${DEBUG:-10}
WITH_GDB=${WITH_GDB:-""}

d=${PWD##*/}
backend=${BACKEND:-"sfs"}

if [[ "${d}" != "build" ]]; then
	[[ ! -d "build" ]] && echo "can't find build directory" && exit 1
	pushd build || exit 1
fi

build_only=false

if [[ $# -gt 0 ]]; then
  if [[ "${1}" == "-b" ]]; then
    build_only=true
  fi
fi


CCACHE_DIR=/srv/containers/joao/s3gw-ceph-ccache ninja -j 20 bin/radosgw || \
	exit 1

args="--rgw-sfs-data-path $(pwd)/dev/rgw.foo"
if [[ "${backend}" == "dbstore" ]]; then
	args="--rgw-dbstore-data-path $(pwd)/dev/rgw.foo"
fi

maybe_gdb() {
	if [[ -n "${WITH_GDB}" ]]; then
		gdb --args $*
	else
		$*
	fi
}


[[ ! -d "$(pwd)/dev/rgw.foo" ]] && mkdir -p $(pwd)/dev/rgw.foo

if $build_only ; then
  echo "not running, build-only requested!"
  exit 0
fi

maybe_gdb bin/radosgw \
	--rgw-backend-store=${backend} \
	${args} \
	-i foo \
	--debug-rgw ${DEBUG} \
	--no-mon-config \
	--rgw-data $(pwd)/dev/rgw.foo \
	--run-dir $(pwd)/dev/rgw.foo \
	--debug-lockdep 20 \
  --rgw-lc-debug-interval 60 \
  --rgw_sfs_sqlite_profile true \
	-d

