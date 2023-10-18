#!/bin/bash

ourpath=$(realpath $0)
basepath=$(dirname ${ourpath})

s3gw_repo=${basepath}/s3gw.git
ceph_repo=${basepath}/ceph.git
s3tests_repo=${basepath}/s3-tests.git

[[ ! -d "${s3gw_repo}" ]] && \
	echo "missing s3gw.git repo!" && \
	exit 1

[[ ! -d "${ceph_repo}" ]] && \
	echo "missing ceph.git repo!" && \
	exit 1

[[ ! -d "${ceph_repo}/build/bin" ]] && \
	echo "missing ceph.git repo build!" && \
	exit 1

if [[ ! -d "${s3tests_repo}/venv" ]]; then
  echo "setup s3tests repo venv"
  pushd ${s3tests_repo}
  python3 -m venv venv || exit 1
  source venv/bin/activate
  pip install -r requirements.txt || exit 1
  deactivate
  popd
fi

testlst=
if [[ -n "${1}" ]]; then
	testlst=$(realpath ${1})
fi

export DEBUG=1
export CEPH_DIR=${ceph_repo}

[[ -n "${testlst}" ]] && \
  export S3TEST_LIST=${testlst}

if [[ ! -d ${s3tests_repo} ]]; then
	git clone https://github.com/ceph/s3-tests ${s3tests_repo} || exit 1
fi

pushd ${s3tests_repo}
git remote update
git pull

source ${s3tests_repo}/venv/bin/activate

${s3gw_repo}/tools/tests/s3tests-runner.sh

