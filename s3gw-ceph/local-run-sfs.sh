#!/bin/bash

rpath=$(realpath $0)
basedir=$(dirname $rpath)

utils="${basedir}/s3gw-utils.git"

if [[ ! -d "${utils}" ]]; then
  echo "couldn't find s3gw-utils.git!" >/dev/null
  exit 1
fi

S3GW_CCACHE_DIR="MYDIRGOESHERE" \
  S3GW_NPROC=6 \
  ${utils}/s3gw-ceph/run-sfs.sh $* || exit 1

