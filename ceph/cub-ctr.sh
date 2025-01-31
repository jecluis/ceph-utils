#!/bin/bash

ourdir="$(dirname "$(realpath "$0")")"
release_name=
release_version=

usage() {
  cat <<EOF
usage: $0 COMMAND ARGS

Commands:
  build-ctr ARGS    Build a container
  prepare ARGS      Prepare a build from current directory
  build ARGS        Build Ceph from the current directory

Internal Container Commands (do not use directly):
  do-prepare        Prepare a build on the current directory
  do-build          Build Ceph from the current directory

Arguments:
  --release-name | -n RELEASE          Specify release name
  --release-version | -r VERSION       Specify release version

EOF
}

build_ctr() {
  local cephdir="${PWD}"

  [[ -z "${release_name}" ]] &&
    echo "error: missing release name" && exit 1
  [[ -z "${release_version}" ]] &&
    echo "error: missing release version" && exit 1

  echo "   release name: ${release_name}"
  echo "release version: ${release_version}"

  echo -n "check release validity... "
  local ctrdir="${ourdir}/containers"

  [[ ! -d "${ctrdir}" ]] &&
    echo "ERROR" &&
    echo "error: unable to find containers directory at '${ctrdir}'" \
      >/dev/stderr &&
    exit 1

  local rel_dockerfile="${ctrdir}/Dockerfile.${release_name}"
  [[ ! -f "${rel_dockerfile}" ]] &&
    echo "ERROR" &&
    echo "error: unable to find dockerfile for '${release_name}'" \
      >/dev/stderr &&
    exit 1

  echo "OK"

  echo -n "check ceph source directory... "
  [[ ! -e "${cephdir}/ceph.spec.in" ]] &&
    echo "ERROR" &&
    echo "error: current directory is not a ceph source directory" &&
    exit 1

  echo "OK"

  dt="$(date +%Y%m%dT%H%M%S)"
  tmp_dir="/tmp/cub-ctr-build-${release_name}-${release_version}-${dt}"

  echo "create temp dir at '${tmp_dir}'"
  mkdir "${tmp_dir}" || exit 1

  echo "copy files to temp dir"
  mkdir "${tmp_dir}"
  cp "${cephdir}/ceph.spec.in" "${tmp_dir}/"
  cp "${cephdir}/install-deps.sh" "${tmp_dir}/"
  cp -r "${ourdir}/cub-ctr.sh" "${tmp_dir}/"

  echo "run container build in temp dir context"
  podman build \
    -f "${rel_dockerfile}" \
    -t "cub-dev/${release_name}:${release_version}" \
    "${tmp_dir}" || exit 1

  rm -fr "${tmp_dir}"
}

run_ctr_prepare() {
  local cephdir="${PWD}"

  [[ -z "${release_name}" ]] &&
    echo "error: missing release name" && exit 1
  [[ -z "${release_version}" ]] &&
    echo "error: missing release version" && exit 1

  [[ ! -e "${cephdir}/ceph.spec.in" ]] &&
    echo "error: current directory is not a ceph source directory" &&
    exit 1

  img="cub-dev/${release_name}:${release_version}"

  podman run -it \
    --userns=keep-id \
    --security-opt label=disable \
    --volume "${cephdir}":/ceph \
    --volume "${ourdir}":/tools/cub \
    "${img}" do-prepare --release-name "${release_name}"
}

run_do_prepare() {

  [[ -z "${release_name}" ]] &&
    echo "error: missing 'release name' to 'do-prepare'" >/dev/stderr &&
    exit 1

  local extra_args=()
  config_file="/tools/cub/containers/config.${release_name}"
  if [[ -e "${config_file}" ]]; then
    readarray -t extra_args <"${config_file}"
    echo "prepare with extra args:"
    for i in "${extra_args[@]}"; do
      echo "> ${i}"
    done
  fi

  pushd /ceph
  ./do_cmake.sh ${extra_args[@]}
  #  /tools/cub/cub.sh prepare
}

run_ctr_build() {
  local cephdir="${PWD}"
  [[ -z "${release_name}" ]] &&
    echo "error: missing release name" >/dev/stderr && exit 1
  [[ -z "${release_version}" ]] &&
    echo "error: missing release version" >/dev/stderr && exit 1

  [[ ! -e "${cephdir}/ceph.spec.in" ]] &&
    echo "error: current directory is not a ceph source directory" \
      >/dev/stderr &&
    exit 1

  img="cub-dev/${release_name}:${release_version}"

  [[ ! -e "${cephdir}/.cub.cfg" ]] &&
    echo "error: missing .cub.cfg, please generate config" \
      >/dev/stderr && exit 1

  local host_ccache_export="$(grep 'CUB_CCACHE_DIR' .cub.cfg)"
  [[ -z "${host_ccache_export}" ]] &&
    echo "error: missing host ccache dir in .cub.cfg" \
      >/dev/stderr && exit 1

  local host_ccache="${host_ccache_export##*=}"
  [[ -z "${host_ccache}" ]] &&
    echo "error: missing host ccache dir in .cub.cfg" >/dev/stderr && exit
  [[ ! -d "${host_ccache}" ]] &&
    echo "error: host ccache dir does not exist at '${host_ccache}'" \
      >/dev/stderr &&
    exit 1

  podman run -it \
    --userns=keep-id \
    --security-opt label=disable \
    --volume "${cephdir}":/ceph \
    --volume "${host_ccache}":/ccache \
    --volume "${ourdir}":/tools/cub \
    "${img}" do-build
}

run_do_build() {
  pushd /ceph

  [[ ! -e ".cub.cfg" ]] &&
    echo "error: missing .cub.cfg in ceph directory" >/dev/stderr &&
    exit 1

  cp .cub.cfg /tmp/cub-ctr-build.cfg || exit 1
  sed -i 's/CUB_CCACHE_DIR=.*/CUB_CCACHE_DIR=\/ccache/' \
    /tmp/cub-ctr-build.cfg ||
    exit 1

  /tools/cub/cub.sh -c /tmp/cub-ctr-build.cfg build
}

run_ctr_vstart() {
  local cephdir="${PWD}"
  [[ -z "${release_name}" ]] &&
    echo "error: missing release name" >/dev/stderr && exit 1
  [[ -z "${release_version}" ]] &&
    echo "error: missing release version" >/dev/stderr && exit 1

  [[ ! -e "${cephdir}/ceph.spec.in" ]] &&
    echo "error: current directory is not a ceph source directory" \
      >/dev/stderr &&
    exit 1

  [[ ! -d "${cephdir}/build" ]] &&
    echo "error: ceph hasn't been built yet" >/dev/stderr && exit 1

  img="cub-dev/${release_name}:${release_version}"

  podman run -it \
    --userns=keep-id \
    --security-opt label=disable \
    --volume "${cephdir}":/ceph \
    --volume "${ourdir}":/tools/cub \
    "${img}" do-run-vstart
}

do_run_vstart() {
  pushd /ceph

  [[ ! -d "build" ]] &&
    echo "error: ceph has not been built" >/dev/stderr && exit 1

  pushd build
  echo "run vstart cluster"
  ../src/vstart.sh -n -l -d || exit 1

  echo "run infinitely"
  sleep infinity
}

run_ctr_exec() {
  local cephdir="${PWD}"
  [[ -z "${release_name}" ]] &&
    echo "error: missing release name" >/dev/stderr && exit 1
  [[ -z "${release_version}" ]] &&
    echo "error: missing release version" >/dev/stderr && exit 1

  [[ ! -e "${cephdir}/ceph.spec.in" ]] &&
    echo "error: current directory is not a ceph source directory" \
      >/dev/stderr &&
    exit 1

  [[ ! -d "${cephdir}/build" ]] &&
    echo "error: ceph hasn't been built yet" >/dev/stderr && exit 1

  img="cub-dev/${release_name}:${release_version}"

  podman run -it \
    --userns=keep-id \
    --security-opt label=disable \
    --volume "${cephdir}":/ceph \
    --volume "${ourdir}":/tools/cub \
    --entrypoint "/bin/bash" \
    "${img}"
}

main() {

  local cmds=()
  local args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --release-name | -n)
      [[ -z "${2}" || "${2::1}" == "-" ]] &&
        echo "error: missing argument for '${1}'" >/dev/stderr &&
        exit 1
      release_name="${2}"
      shift 1
      ;;
    --release-version | -r)
      [[ -z "${2}" || "${2::1}" == "-" ]] &&
        echo "error: missing argument for '${1}'" >/dev/stderr &&
        exit 1
      release_version="${2}"
      shift 1
      ;;
    -*)
      args+=("${1}")
      if [[ -n "${2}" && "${2::1}" != "-" ]]; then
        args+=("${2}")
        shift 1
      fi
      ;;
    *) cmd+=("${1}") ;;
    esac
    shift 1
  done

  [[ ${#cmd[@]} -eq 0 ]] &&
    echo "error: missing command" >/dev/stderr &&
    exit 1

  case "${cmd[0]}" in
  build-ctr)
    build_ctr "${args[@]}"
    ;;
  prepare)
    run_ctr_prepare
    ;;
  build)
    run_ctr_build
    ;;
  run-vstart)
    run_ctr_vstart
    ;;
  exec)
    run_ctr_exec
    ;;
  do-prepare)
    run_do_prepare
    ;;
  do-build)
    run_do_build
    ;;
  do-run-vstart)
    run_vstart
    ;;
  *)
    echo "error: unknown command '${cmd}'" >/dev/stderr
    usage >/dev/stderr
    exit 1
    ;;
  esac
}

main "$@"
