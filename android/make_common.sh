#!/usr/bin/env bash

# TODO: Long / better opts
# TODO: Optional avb

# shellcheck disable=SC2015
# shellcheck disable=SC2154
# shellcheck disable=SC2206
# shellcheck source=/dev/null

apply_user_scripts() {
  user_scripts_arr=( $user_scripts )
  for user_script in "${user_scripts_arr[@]}"
  do
    ${user_script}
  done
}

ccache_init() {
  ccache -M "${ccache_size}"
  ccache -o compression=true
}

git_reset_clean() {
  for cmd in am cherry-pick merge rebase revert
  do
    git $cmd --abort 2>/dev/null || true
  done
  git add --all
  git reset --hard
  if git remote -v | grep -i "chromium/src" > /dev/null
  then
    git clean -ffdx
  else
    git clean -ffd
  fi
}

clean_repo() {
  rm -rf ./out ./releases ./*.zip
  find . -type f -name "index.lock" -delete
  repo forall -c bash -c "git_reset_clean" &>/dev/null || true
}

sync_repo() {
  cd .repo/repo && git pull --force
  cd - >/dev/null
  n=0 r="${retries}"
  set +e
  until [[ "${n}" -gt "${r}" ]]
  do
    repo sync --force-sync -j"${sync_jobs}" && \
    repo forall -c "git lfs pull" && break # only needed for pre-lfs existing repos
    n=$((n+1))
    sleep 3
    [[ "${n}" -le "${r}" ]] && echo "WARN: repo sync failed, retry ${n} of ${r}"
    [[ "${n}" -gt "${r}" ]] && echo "FATAL: repo sync exceeded max retries" && exit 1
  done
  set -e
}

repo_safe_dir() {
  # Allow existing repo to work in container (will change some ownership to root)
  git config --global --add safe.directory "${PWD}/.repo/manifests"
  git config --global --add safe.directory "${PWD}/.repo/repo"
  while read -r path
  do
    git config --global --add safe.directory "${PWD}"/"${path}"
  done < .repo/project.list
}

repo_init_ref() {
  if [[ "${manifest_tag,,}" == "latest" && -z "${manifest_latest_tag}" ]]
  then
    manifest_latest_tag="$(eval "curl -sL ${latest_tag_cmd}")"
    manifest_tag=${manifest_latest_tag}
  fi
  if [[ ! "${manifest_tag}" =~ (^[[:digit:]]{8,10}$|^${calyxos_version_major}.|^dev|^$) ]]
  then
    echo "FATAL: Manifest tag: \"${manifest_tag}\" does not match expected format" && usage
  fi
  echo "INFO: Building ${android_platform^} on ref: \"${manifest_tag}\""
}

print_env() {
  epoch=$(printf "%.0f" $EPOCHREALTIME)
  export epoch
  [[ "${PRINT_ENV}" == "true" ]] && env | sort > "${device_out}"/"${device}"-"${epoch}".env || true
}

build_date=$(TZ=UTC date +%Y%m%d)
sync_jobs=$(nproc)
export build_date
export sync_jobs

export -f git_reset_clean
export android_dname="/CN=Android/"
export chromium_dname="CN=Chromium"
export ccache_size=50G
export clean_repo=0
export print_env=0
export retries=5
export roomservice=0
export sign_build=0
export variant="userdebug"
export yarn=0
export manifest_tag="dev"
export mapbox_key="apikey"

[[ -n "${env_vars}" ]] && export "${env_vars?}"

while getopts ":a:b:c:d:e:f:g:j:k:m:n:o:p:q:t:u:v:x:z:hilrswy" opt; do
  case $opt in
    a) export android_top="$OPTARG" ;;
    b) build_type="$OPTARG" ;;
    c) ccache_size="$OPTARG" ;;
    d) device_list="$OPTARG" ;;
    e) env_vars="$OPTARG" ;;
    f) variant="$OPTARG" ;;
    g) export android_dname="$OPTARG" ;;
    h) usage ;;
    i) export OFFICIAL_BUILD=true ;;
    j) sync_jobs="$OPTARG" ;;
    k) export keys_dir="$OPTARG" ;;
    l) clean_repo=1 ;;
    m) gms_makefile="$OPTARG" ;;
    n) kernel_dir="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    p) retries="$OPTARG" ;;
    q) export chromium_dname="$OPTARG" ;;
    r) roomservice=1 ;;
    s) sign_build=1 ;;
    t) manifest_tag="$OPTARG" ;;
    u) user_scripts="$OPTARG" ;;
    v) android_version="$OPTARG" ;;
    w) print_env=1 ;;
    x) chromium_dir="$OPTARG" ;;
    y) yarn=1 ;;
    z) mapbox_key="$OPTARG" ;;
    :) echo -e "FATAL: Option -$OPTARG requires an argument\n"
       usage ;;
    \?) echo -e "FATAL: Invalid option:-$OPTARG\n"
       usage ;;
  esac
done
shift $((OPTIND-1))

# Add (Docker) environment if it exists
[[ -n "${ANDROID_VERSION}" ]] && export android_version=${ANDROID_VERSION}
[[ -n "${BUILD_TYPE}" ]] && export build_type=${BUILD_TYPE}
[[ -n "${BUILD_VARIANT}" ]] && export variant=${BUILD_VARIANT}
[[ -n "${CCACHE_SIZE}" ]] && export ccache_size=${CCACHE_SIZE}
[[ -n "${DEVICES}" ]] && export device_list=${DEVICES}
[[ -n "${DNAME_ANDROID}" ]] && export android_dname=${DNAME_ANDROID}
[[ -n "${DNAME_CHROMIUM}" ]] && export chromium_dname=${DNAME_CHROMIUM}
[[ -n "${GMS_MAKEFILE}" ]] && export gms_makefile=${GMS_MAKEFILE}
[[ -n "${MANIFEST_TAG}" ]] && export manifest_tag=${MANIFEST_TAG}
[[ -n "${SYNC_JOBS}" ]] && export sync_jobs=${SYNC_JOBS}
[[ -n "${SYNC_RETRIES}" ]] && export retries=${SYNC_RETRIES}
[[ -n "${USER_SCRIPTS}" ]] && export user_scripts=${USER_SCRIPTS}
[[ -n "${DELETE_ROOMSERVICE}" && "${DELETE_ROOMSERVICE}" != "false" ]] && export roomservice=1
[[ -n "${CLEAN_REPO}" && "${CLEAN_REPO}" != "false" ]] && export clean_repo=1
[[ -n "${SIGN_BUILD}" && "${SIGN_BUILD}" != "false" ]] && export sign_build=1
[[ -n "${PRINT_ENV}" && "${PRINT_ENV}" != "false" ]] && export print_env=1
[[ -n "${YARN}" && "${YARN}" != "false" ]] && export yarn=1

[[ -f /.dockerenv ]] && export android_top=/android_build/src
[[ -f /.dockerenv ]] && export keys_dir=/android_build/keys
[[ -f /.dockerenv ]] && export out_dir=/android_build/out
[[ -f /.dockerenv ]] && export kernel_dir=/android_build/kernel
[[ -f /.dockerenv ]] && export chromium_dir=/android_build/chromium

# Validations
[[ -z "${device_list}" ]] && echo "FATAL: Device list (-d) or DEVICES is required" && exit 1
[[ -z "${android_top}" ]] && echo "FATAL: Top dir (-a) or -v \$TOP/android_build/src is required" && exit 1

# Set up ccache
if [[ -n "${ccache_size}" ]]
then
  ccache_init
fi

# Save workdir
export BUILD_HOME="${PWD}"

# Update depot tools
cd depot_tools && git pull || true

# If android_version is not set, try to calculate platform and version
cd "${android_top}"
if [[ -n "${android_version}" ]]
then
  android_platform=${android_version%%-*}
  android_version_number=${android_version##*-}
elif [[ -d .repo ]]
then
  for os in lineageos calyxos grapheneos
  do
    if grep -q "${os}" .repo/manifests/default.xml
    then
      android_platform=${os}
    fi
  done
  android_version_number=$(grep refs/heads .repo/manifests/default.xml | cut -d\" -f2 | cut -d/ -f3 | cut -d- -f2 | tr -d "[:alpha:]" | uniq || true)
  if [[ -z "${android_version_number}" ]]
  then
    android_version_number=$(grep 'revision="refs/tags/android-' .repo/manifests/default.xml | cut -d- -f2 | cut -d. -f1 || true)
  fi
fi

[[ -z "${android_platform}" ]] && echo "FATAL: Supported Android platform not found" && exit 1
[[ ! "${android_version_number}" =~ ^[[:digit:]]{1,2}?.[[:digit:]]$ ]] && echo "FATAL: Could not determine Android version number" && exit 1

export android_platform=${android_platform,,}
export android_version_number ANDROID_VERSION=${android_version_number}
export build_path="${BUILD_HOME}"/android/"${android_platform}"
export AVB_TOOL="${android_top}/external/avb/avbtool.py"
export MAKE_KEY="${android_top}/development/tools/make_key"

. "${build_path}"/make_"${android_platform}".sh 

