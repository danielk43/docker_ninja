#!/usr/bin/env bash

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

git_clean_repo() {
  rm -rf ./out ./releases ./*.zip ./bazel-*
  find . -type f -name "index.lock" -delete
  "${BUILD_HOME}"/android/git_deep_clean.sh "$@" || true
}

sync_repo() {
  pushd .repo/repo >/dev/null && git pull --force
  popd >/dev/null
  n=0 r="${retries}"
  set +e
  until [[ "${n}" -gt "${r}" ]]
  do
    repo sync --force-sync -j"${sync_jobs}" && break # only needed for pre-lfs existing repos
    n=$((n+1))
    sleep 3
    [[ "${n}" -le "${r}" ]] && echo "WARN: repo sync failed, retry ${n} of ${r}"
    [[ "${n}" -gt "${r}" ]] && echo "FATAL: repo sync exceeded max retries" && exit 1
  done
  set -e
}

# Allow existing repo to work in container (will change some ownership to root)
repo_safe_dir() {
  if [[ -d "./.git" ]]
  then
    git config --global --add safe.directory "${PWD}"
    # shellcheck disable=SC2046
    for repository in $(dirname $(find . -mindepth 2 -name .git -printf "%P\n"))
    do
      git config --global --add safe.directory "${PWD}/${repository}"
    done
  elif [[ -d "./.repo" ]]
  then
    git config --global --add safe.directory "${PWD}/.repo/manifests"
    git config --global --add safe.directory "${PWD}/.repo/repo"
    while read -r project
    do
      git config --global --add safe.directory "${PWD}"/"${project}"
    done < .repo/project.list >/dev/null || true
  fi
}

repo_init_ref() {
  if [[ "${release_tag,,}" == "latest" && -z "${release_latest_tag}" ]]
  then
    release_latest_tag="$(eval "curl -fsSL ${latest_tag_cmd}")"
    release_tag=${release_latest_tag}
  fi
  if [[ ! "${release_tag}" =~ (^[[:digit:]]{8,10}$|^${calyxos_version_major}.|^dev|^$) ]]
  then
    echo "FATAL: Manifest tag: \"${release_tag}\" does not match expected format" && usage
  fi
  echo "INFO: Building ${android_platform^} on ref: \"${release_tag}\""
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

export android_dname="/CN=Android/"
export chromium_dname="CN=Chromium"
export ccache_size=50G
export clean_repo=0
export expire_since="30.days.ago"
export persist_vendor=0
export print_env=0
export prune_since="2.weeks.ago"
export retries=5
export roomservice=0
export sign_build=0
export variant="userdebug"
export release_tag="dev"

# Add environment
[[ -n "${ANDROID_VERSION}" ]] && export android_version=${ANDROID_VERSION}
[[ -n "${BUILD_TYPE}" ]] && export build_type=${BUILD_TYPE^^}
[[ -n "${BUILD_VARIANT}" ]] && export variant=${BUILD_VARIANT,,}
[[ -n "${CCACHE_SIZE}" ]] && export ccache_size=${CCACHE_SIZE}
[[ -n "${DEVICES}" ]] && export device_list=${DEVICES}
[[ -n "${DNAME_ANDROID}" ]] && export android_dname=${DNAME_ANDROID}
[[ -n "${DNAME_CHROMIUM}" ]] && export chromium_dname=${DNAME_CHROMIUM}
[[ -n "${EXPIRE_SINCE}" ]] && export expire_since=${EXPIRE_SINCE}
[[ -n "${GMS_MAKEFILE}" ]] && export gms_makefile=${GMS_MAKEFILE}
[[ -n "${PRUNE_SINCE}" ]] && export prune_since=${PRUNE_SINCE}
[[ -n "${RELEASE_TAG}" ]] && export release_tag=${RELEASE_TAG}
[[ -n "${SYNC_JOBS}" ]] && export sync_jobs=${SYNC_JOBS}
[[ -n "${SYNC_RETRIES}" ]] && export retries=${SYNC_RETRIES}
[[ -n "${USER_SCRIPTS}" ]] && export user_scripts=${USER_SCRIPTS}
[[ -n "${DELETE_ROOMSERVICE}" && "${DELETE_ROOMSERVICE}" != "false" ]] && export roomservice=1
[[ -n "${PERSIST_VENDOR}" && "${PERSIST_VENDOR}" != "false" ]] && export persist_vendor=1
[[ -n "${CLEAN_REPO}" && "${CLEAN_REPO}" != "false" ]] && export clean_repo=1
[[ -n "${SIGN_BUILD}" && "${SIGN_BUILD}" != "false" ]] && export sign_build=1
[[ -n "${PRINT_ENV}" && "${PRINT_ENV}" != "false" ]] && export print_env=1

export android_top=/android_build/src
export keys_dir=/android_build/keys
export out_dir=/android_build/out
export kernel_dir=/android_build/kernel
export chromium_dir=/android_build/chromium

# Begin logging if dir is mounted
[[ -d /android_build/log ]] && exec &>> /android_build/log/build_"$(date +%F_%H-%M-%S)".log

# Validations
[[ -z "${android_top}" ]] && echo "FATAL: Top dir (-v \$TOP:/android_build/src) is required" && exit 1

# Set up ccache
if [[ -n "${ccache_size}" ]]
then
  ccache_init
fi

# Save workdir
export BUILD_HOME="${PWD}"

# Update depot tools
pushd depot_tools >/dev/null && git pull origin main || true
popd >/dev/null

# If android_version is not set, try to calculate platform and version
pushd "${android_top}" >/dev/null
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

devices=$(printf %s "${device_list,,}" | sed -e "s/[[:punct:]]\+/ /g")
export devices
export android_platform=${android_platform,,}
export android_version_number ANDROID_VERSION=${android_version_number}
export build_path="${BUILD_HOME}"/android/"${android_platform}"
export AVB_TOOL="${android_top}/external/avb/avbtool.py"
export MAKE_KEY="${android_top}/development/tools/make_key"

[[ -n "${devices}" ]] && echo "INFO: Device list: ${devices}"
. "${build_path}"/make_"${android_platform}".sh

