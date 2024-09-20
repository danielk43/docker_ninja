#!/usr/bin/env bash

# shellcheck disable=SC2015,SC2046,SC2206
# shellcheck source=/dev/null

set -eo pipefail

build_date=$(TZ=UTC date +%Y%m%d)
sync_jobs=$(nproc)
ccache_size=50G
variant="userdebug"
retries=7
roomservice=0
sign_lineageos=0
yarn=0

usage() {
  echo "Usage:"
  echo "  ./build_android.sh [ options ]"
  echo
  echo "Each device's GrapheneOS signing key must be set in the environment as"
  echo "KEYS_PASSWORD_<DEVICE>: e.g., \$KEYS_PASSWORD_RAVEN"
  echo
  echo "VANADIUM_PASSWORD in the environment and -v option together trigger browser build"
  echo "Vanadium keystore password must be over six characters"
  echo
  echo "  Options:"
  echo "    -a Android repo top (user-provided croot dir; same as \$ANDROID_BUILD_TOP)"
  echo "    -b lineageos Build type (defaults to unofficial)"
  echo "    -c Ccache size (defaults to 50G)"
  echo "    -d space-separated Device codenames to build (\"device1 device2 ...\")"
  echo "    -e space-separated extra Env vars to be exported (\"k1=v1 k2=v2 ...\")"
  echo "    -f target build Flavor / variant (defaults to userdebug. also accepts user, eng)"
  echo "    -h print this Help menu and exit"
  echo "    -i offIcial grapheneos build (must configure update server url)"
  echo "    -j number of Jobs during repo sync (defaults to nproc)"
  echo "    -k lineageos Keys dir (enforced if -s is set, requires each device dir with keyfiles inside)"
  echo "    -m gms Makefle (set filename if vendor/partner_gms exists, also sets WITH_GMS=true)"
  echo "    -n grapheneos kerNel root directory (above each device family repo)"
  echo "    -o Out dir for completed build images (defaults to \$ANDROID_BUILD_TOP/releases)"
  echo "    -p number of retries for rePo sync if errors encountered (defaults to 7)"
  echo "    -r delete Roomservice.xml (if local_manifests are user-defined)"
  echo "    -s Sign lineageos build (requires keys, see https://wiki.lineageos.org/signing_builds)"
  echo "    -t grapheneos release Tag (or \"latest\" for latest stable, omit or \"dev\" for development)"
  echo "    -u space-separated paths to User scripts (\"/path/to/user.sh /path/to/patch.sh ...\")"
  echo "    -v android Version (in format \"grapheneos-xx\" for grapheneos and \"lineageos-xx.x\" for lineageos)"
  echo "    -x vanadium dir (build browser for grapheneos. remote name must contain \"vanadium\")"
  echo "    -y Yarn install adevtool and extract grapheneos vendor files"
  echo
  echo "  Example:"
  echo "    ./build_android.sh -a \$LOS_TOP -d \"barbet lynx\" -f user \\"
  echo "    -k \"\$HOME/.android-certs\" -m gms_custom.mk -rs -u \"\$HOME/patch.sh\" -v lineageos-20.0"
  echo
  exit 1
}

while getopts ":a:b:c:d:e:f:j:k:m:n:o:p:t:u:v:x:hirsy" opt; do
  case $opt in
    a) android_top="$OPTARG" ;;
    b) build_type="$OPTARG" ;;
    c) ccache_size="$OPTARG" ;;
    d) device_list="$OPTARG" ;;
    e) env_vars="$OPTARG" ;;
    f) variant="$OPTARG" ;;
    h) usage ;;
    i) export OFFICIAL_BUILD=true ;;
    j) sync_jobs="$OPTARG" ;;
    k) keys_dir="$OPTARG" ;;
    m) gms_makefile="$OPTARG" ;;
    n) kernel_dir="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    p) retries="$OPTARG" ;;
    r) roomservice=1 ;;
    s) sign_lineageos=1 ;;
    t) grapheneos_tag="$OPTARG" ;;
    u) user_scripts="$OPTARG" ;;
    v) android_version="$OPTARG" ;;
    x) vanadium_dir="$OPTARG" ;;
    y) yarn=1 ;;
    :) echo -e "FATAL: Option -$OPTARG requires an argument\n"
       usage ;;
    \?) echo -e "FATAL: Invalid option:-$OPTARG\n"
       usage ;;
  esac
done
shift $((OPTIND-1))

git_reset_clean() {
  for cmd in am cherry-pick merge rebase revert
  do
    git $cmd --abort 2> /dev/null || true
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

export -f git_reset_clean

ccache_init() {
  ccache -M "${ccache_size}"
  ccache -o compression=true
}

clean_repo() {
  rm -rf out releases ./*.zip
  find . -type f -name "index.lock" -delete
}

sync_repo() {
  repo forall -c bash -c "git_reset_clean" &> /dev/null || true
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
  for path in $(repo list -fp); do git config --global --add safe.directory "${path}"; done
}

apply_user_scripts() {
  user_scripts_arr=( $user_scripts )
  for user_script in "${user_scripts_arr[@]}"
  do
    ${user_script}
  done
}

# Export variables
[[ -n "${env_vars}" ]] && export "${env_vars?}"
[[ -n "${USER_NAME}" ]] && export GIT_AUTHOR_NAME=${USER_NAME} GIT_COMMITTER_NAME=${USER_NAME}
[[ -n "${USER_EMAIL}" ]] && export GIT_AUTHOR_EMAIL=${USER_EMAIL} GIT_COMMITTER_EMAIL=${USER_EMAIL}

# Add (Docker) environment if it exists
[[ -n "${ANDROID_VERSION}" ]] && export android_version=${ANDROID_VERSION}
[[ -n "${BUILD_TYPE}" ]] && export build_type=${BUILD_TYPE}
[[ -n "${BUILD_VARIANT}" ]] && export variant=${BUILD_VARIANT}
[[ -n "${CCACHE_SIZE}" ]] && export ccache_size=${CCACHE_SIZE}
[[ -n "${DEVICES}" ]] && export device_list=${DEVICES}
[[ -n "${GMS_MAKEFILE}" ]] && export gms_makefile=${GMS_MAKEFILE}
[[ -n "${GRAPHENEOS_TAG}" ]] && export grapheneos_tag=${GRAPHENEOS_TAG}
[[ -n "${SYNC_JOBS}" ]] && export sync_jobs=${SYNC_JOBS}
[[ -n "${SYNC_RETRIES}" ]] && export retries=${SYNC_RETRIES}
[[ -n "${USER_SCRIPTS}" ]] && export user_scripts=${USER_SCRIPTS}
[[ -n "${DELETE_ROOMSERVICE}" && "${DELETE_ROOMSERVICE}" != "false" ]] && export roomservice=1
[[ -n "${SIGN_LINEAGEOS}" && "${SIGN_LINEAGEOS}" != "false" ]] && export sign_lineageos=1
[[ -n "${YARN}" && "${YARN}" != "false" ]] && export yarn=1

[[ -f /.dockerenv ]] && export android_top=/android_build/src
[[ -f /.dockerenv ]] && export kernel_dir=/android_build/kernel
[[ -f /.dockerenv ]] && export keys_dir=/android_build/keys
[[ -f /.dockerenv ]] && export out_dir=/android_build/out
[[ -f /.dockerenv ]] && export vanadium_dir=/android_build/vanadium

# Validations
[[ -z "${device_list}" ]] && echo "FATAL: Device list (-d) is required" && usage
[[ -z "${android_top}" ]] && echo "FATAL: Top dir (-a) is required" && usage

# Set up ccache
if [[ -n "${ccache_size}" && -d "${CCACHE_DIR}" ]]
then
  ccache_init
fi

# Update depot tools
cd depot_tools && git pull

cd "${android_top}"

# Determine whether building for grapheneos or lineageos. If var does not exist, try to calculate it
if [[ -n "${android_version}" ]]
then
  if grep -Eqv "grapheneos|lineageos" <<< "${android_version,,}"
  then
    echo "FATAL: Android Version must contain \"grapheneos\" or \"lineageos\"" && usage
  else
    android_platform=${android_version%%-*}
    android_version_number=${android_version##*-}
  fi
elif [[ -d .repo ]] ; then
  if grep -q lineageos .repo/manifests/default.xml
  then
    android_platform=lineageos
  elif grep -q grapheneos .repo/manifests/default.xml
  then
    android_platform=grapheneos
  fi
  android_version_number=$(grep refs/heads .repo/manifests/default.xml | cut -d\" -f2 | cut -d/ -f3 | cut -d- -f2 | uniq || true)
  if [[ -z "${android_version_number}" ]]
  then
    android_version_number=$(grep 'revision="refs/tags/android-' .repo/manifests/default.xml | cut -d- -f2 | cut -d. -f1 || true)
  fi
fi
[[ ! "${android_platform}" =~ ^grapheneos$|^lineageos$ ]] && echo "FATAL: Could not determine Android platform" && usage
[[ ! "${android_version_number}" =~ ^[[:digit:]]{2}?.[[:digit:]]$ ]] && echo "FATAL: Could not determine Android version number" && usage
export android_platform=${android_platform,,}
export android_version_number

# Build Vanadium once, outside of devices loop
if grep -q "${android_platform}" <<< "grapheneos"
then
  if [[ -n "${VANADIUM_PASSWORD}" && -d ${vanadium_dir} ]]
  then
    cd "${vanadium_dir}"
    [[ -f "args.gn" ]] || git clone https://github.com/GrapheneOS/Vanadium.git .
    clean_repo
    [[ -f /.dockerenv ]] && git config --global --add safe.directory "${vanadium_dir}"
    git reset --hard && git clean -ffd
    git fetch --all --force --tags --prune --prune-tags
    git checkout main # TODO: add tags checkout functionality
    git pull --rebase -X ours "$(git remote)" "$(git branch --show-current)" # rebase on tags also? git describe --exact-match --tags
    vanadium_current_version=$(grep android_default_version_name args.gn | cut -d\" -f2)

    if [[ ! -f vanadium.keystore ]]
    then
      echo -e "${VANADIUM_PASSWORD}\n${VANADIUM_PASSWORD}" | \
      keytool -genkey -v -keystore vanadium.keystore -storetype pkcs12 -alias vanadium \
      -keyalg RSA -keysize 4096 -sigalg SHA512withRSA -validity 10000 -dname "cn=GrapheneOS"
    fi

    keystore_sha=$(echo "${VANADIUM_PASSWORD}" | keytool -export-cert -alias vanadium -keystore vanadium.keystore | sha256sum | awk '{print $1}')
    sed -i "s/certdigest.*/certdigest = \"${keystore_sha}\"/" args.gn

    [[ ! -d src ]] && fetch --nohooks android
    cd src
    [[ -f /.dockerenv ]] && git config --global --add safe.directory "${PWD}" \
                         && for repository in $(dirname $(find . -type d -name .git -printf "%P\n"))
                            do
                              git config --global --add safe.directory "${PWD}"/"${repository}"
                            done
    rm -rf .git/*-apply && git_reset_clean &> /dev/null
    git submodule foreach "git reset --hard; git clean -ffdx" &> /dev/null || true
    git fetch --all --force --tags --prune --prune-tags
    git checkout --force "${vanadium_current_version}"
    git am --whitespace=nowarn --keep-non-patch "${vanadium_dir}"/patches/*.patch
    cd "${vanadium_dir}" && gclient sync -D --with_branch_heads --with_tags --jobs "${sync_jobs}" && cd src
    mkdir -p out/Default
    cp -fp "${vanadium_dir}"/args.gn out/Default
    gn gen out/Default
    gn args out/Default --list > out/Default/gn_list

    chrt -b 0 autoninja -C out/Default trichrome_webview_64_32_apk \
    trichrome_chrome_64_32_apk trichrome_library_64_32_apk vanadium_config_apk

    echo "${VANADIUM_PASSWORD}" | "${vanadium_dir}"/generate-release out
    cd "${android_top}"
  fi
fi

# Initialize Device Build
devices=$(printf %s "${device_list,,}" | sed -e "s/[[:punct:]]\+/ /g")
echo "INFO: Device list: ${devices}"
for device in ${devices}
do
  export device

  # Link keys (containerized link will not be found on host)
  if [[ "${keys_dir}" != "${android_top}/keys" ]]
  then
    mkdir keys 2> /dev/null || true
    ln -s "${keys_dir}"/"${device}" "${android_top}"/keys 2> /dev/null || true
  fi

  # Create outfile directory
  [[ -z "${out_dir}" ]] && export out_dir="${ANDROID_BUILD_TOP}/releases"
  [[ "${out_dir}" != "${ANDROID_BUILD_TOP}/releases" || "${android_platform}" != "grapheneos" ]] && \
  mkdir -p "${out_dir}"/"${device}" 2> /dev/null || true

  if grep -q "${android_platform}" <<< "lineageos"
  then
    [[ "${sign_lineageos}" == "1" && -z "${keys_dir}" ]] && echo "Keys Dir is required if signing build" && usage

    [[ -n "${build_type}" ]] && export LINEAGE_BUILDTYPE="${build_type}"
    [[ -n "${gms_makefile}" ]] && export WITH_GMS="true" GMS_MAKEFILE="${gms_makefile}"

    mkdir -p "${out_dir}"/"${device}"/"${build_date}" 2> /dev/null || true

    echo "INFO: Building LineageOS-${android_version_number} for ${device}"
    # Sync LOS repo
    clean_repo
    [[ -f /.dockerenv ]] && repo_safe_dir
    repo init -u https://github.com/LineageOS/android.git -b lineage-"${android_version_number}" --git-lfs
    [[ "$roomservice" == "1" ]] && rm -f .repo/local_manifests/roomservice.xml
    sync_repo
    source build/envsetup.sh

    (( ${android_version_number%%.*} < 19 )) && echo "Only LineageOS 19 or higher supported" && usage

    # Apply User Scripts
    [[ -n "${user_scripts}" ]] && apply_user_scripts

    if (( "${android_version_number%%.*}" > 20 ))
    then
      target=$(grep target vendor/lineage/vars/aosp_target_release | cut -d= -f2)
      combo=lineage_"${device}-${target}-${variant}"
    else
      combo=lineage_"${device}-${variant}"
    fi

    # Build OS
    if [[ "${sign_lineageos}" == "1" ]]
    then
      echo "INFO: Breakfast combo: ${combo}"
      breakfast "${combo}"
      m target-files-package otatools
    
      device_keys="${keys_dir}/${device}"
      sign_target_files_apks -o -d "${device_keys}" \
      --extra_apks AdServicesApk.apk="${device_keys}"/releasekey \
      --extra_apks HalfSheetUX.apk="${device_keys}"/releasekey \
      --extra_apks OsuLogin.apk="${device_keys}"/releasekey \
      --extra_apks SafetyCenterResources.apk="${device_keys}"/releasekey \
      --extra_apks ServiceConnectivityResources.apk="${device_keys}"/releasekey \
      --extra_apks ServiceUwbResources.apk="${device_keys}"/releasekey \
      --extra_apks ServiceWifiResources.apk="${device_keys}"/releasekey \
      --extra_apks WifiDialog.apk="${device_keys}"/releasekey \
      --extra_apks com.android.adbd.apex="${device_keys}"/com.android.adbd \
      --extra_apks com.android.adservices.apex="${device_keys}"/com.android.adservices \
      --extra_apks com.android.adservices.api.apex="${device_keys}"/com.android.adservices.api \
      --extra_apks com.android.appsearch.apex="${device_keys}"/com.android.appsearch \
      --extra_apks com.android.art.apex="${device_keys}"/com.android.art \
      --extra_apks com.android.bluetooth.apex="${device_keys}"/com.android.bluetooth \
      --extra_apks com.android.btservices.apex="${device_keys}"/com.android.btservices \
      --extra_apks com.android.cellbroadcast.apex="${device_keys}"/com.android.cellbroadcast \
      --extra_apks com.android.compos.apex="${device_keys}"/com.android.compos \
      --extra_apks com.android.configinfrastructure.apex="${device_keys}"/com.android.configinfrastructure \
      --extra_apks com.android.connectivity.resources.apex="${device_keys}"/com.android.connectivity.resources \
      --extra_apks com.android.conscrypt.apex="${device_keys}"/com.android.conscrypt \
      --extra_apks com.android.devicelock.apex="${device_keys}"/com.android.devicelock \
      --extra_apks com.android.extservices.apex="${device_keys}"/com.android.extservices \
      --extra_apks com.android.graphics.pdf.apex="${device_keys}"/com.android.graphics.pdf \
      --extra_apks com.android.hardware.biometrics.face.virtual.apex="${device_keys}"/com.android.hardware.biometrics.face.virtual \
      --extra_apks com.android.hardware.biometrics.fingerprint.virtual.apex="${device_keys}"/com.android.hardware.biometrics.fingerprint.virtual \
      --extra_apks com.android.hardware.boot.apex="${device_keys}"/com.android.hardware.boot \
      --extra_apks com.android.hardware.cas.apex="${device_keys}"/com.android.hardware.cas \
      --extra_apks com.android.hardware.wifi.apex="${device_keys}"/com.android.hardware.wifi \
      --extra_apks com.android.healthfitness.apex="${device_keys}"/com.android.healthfitness \
      --extra_apks com.android.hotspot2.osulogin.apex="${device_keys}"/com.android.hotspot2.osulogin \
      --extra_apks com.android.i18n.apex="${device_keys}"/com.android.i18n \
      --extra_apks com.android.ipsec.apex="${device_keys}"/com.android.ipsec \
      --extra_apks com.android.media.apex="${device_keys}"/com.android.media \
      --extra_apks com.android.media.swcodec.apex="${device_keys}"/com.android.media.swcodec \
      --extra_apks com.android.mediaprovider.apex="${device_keys}"/com.android.mediaprovider \
      --extra_apks com.android.nearby.halfsheet.apex="${device_keys}"/com.android.nearby.halfsheet \
      --extra_apks com.android.networkstack.tethering.apex="${device_keys}"/com.android.networkstack.tethering \
      --extra_apks com.android.neuralnetworks.apex="${device_keys}"/com.android.neuralnetworks \
      --extra_apks com.android.ondevicepersonalization.apex="${device_keys}"/com.android.ondevicepersonalization \
      --extra_apks com.android.os.statsd.apex="${device_keys}"/com.android.os.statsd \
      --extra_apks com.android.permission.apex="${device_keys}"/com.android.permission \
      --extra_apks com.android.resolv.apex="${device_keys}"/com.android.resolv \
      --extra_apks com.android.rkpd.apex="${device_keys}"/com.android.rkpd \
      --extra_apks com.android.runtime.apex="${device_keys}"/com.android.runtime \
      --extra_apks com.android.safetycenter.resources.apex="${device_keys}"/com.android.safetycenter.resources \
      --extra_apks com.android.scheduling.apex="${device_keys}"/com.android.scheduling \
      --extra_apks com.android.sdkext.apex="${device_keys}"/com.android.sdkext \
      --extra_apks com.android.support.apexer.apex="${device_keys}"/com.android.support.apexer \
      --extra_apks com.android.telephony.apex="${device_keys}"/com.android.telephony \
      --extra_apks com.android.telephonymodules.apex="${device_keys}"/com.android.telephonymodules \
      --extra_apks com.android.tethering.apex="${device_keys}"/com.android.tethering \
      --extra_apks com.android.tzdata.apex="${device_keys}"/com.android.tzdata \
      --extra_apks com.android.uwb.apex="${device_keys}"/com.android.uwb \
      --extra_apks com.android.uwb.resources.apex="${device_keys}"/com.android.uwb.resources \
      --extra_apks com.android.virt.apex="${device_keys}"/com.android.virt \
      --extra_apks com.android.vndk.current.apex="${device_keys}"/com.android.vndk.current \
      --extra_apks com.android.vndk.current.on_vendor.apex="${device_keys}"/com.android.vndk.current.on_vendor \
      --extra_apks com.android.wifi.apex="${device_keys}"/com.android.wifi \
      --extra_apks com.android.wifi.dialog.apex="${device_keys}"/com.android.wifi.dialog \
      --extra_apks com.android.wifi.resources.apex="${device_keys}"/com.android.wifi.resources \
      --extra_apks com.google.pixel.camera.hal.apex="${device_keys}"/com.google.pixel.camera.hal \
      --extra_apks com.google.pixel.vibrator.hal.apex="${device_keys}"/com.google.pixel.vibrator.hal \
      --extra_apks com.qorvo.uwb.apex="${device_keys}"/com.qorvo.uwb \
      --extra_apex_payload_key com.android.adbd.apex="${device_keys}"/com.android.adbd.pem \
      --extra_apex_payload_key com.android.adservices.apex="${device_keys}"/com.android.adservices.pem \
      --extra_apex_payload_key com.android.adservices.api.apex="${device_keys}"/com.android.adservices.api.pem \
      --extra_apex_payload_key com.android.appsearch.apex="${device_keys}"/com.android.appsearch.pem \
      --extra_apex_payload_key com.android.art.apex="${device_keys}"/com.android.art.pem \
      --extra_apex_payload_key com.android.bluetooth.apex="${device_keys}"/com.android.bluetooth.pem \
      --extra_apex_payload_key com.android.btservices.apex="${device_keys}"/com.android.btservices.pem \
      --extra_apex_payload_key com.android.cellbroadcast.apex="${device_keys}"/com.android.cellbroadcast.pem \
      --extra_apex_payload_key com.android.compos.apex="${device_keys}"/com.android.compos.pem \
      --extra_apex_payload_key com.android.configinfrastructure.apex="${device_keys}"/com.android.configinfrastructure.pem \
      --extra_apex_payload_key com.android.connectivity.resources.apex="${device_keys}"/com.android.connectivity.resources.pem \
      --extra_apex_payload_key com.android.conscrypt.apex="${device_keys}"/com.android.conscrypt.pem \
      --extra_apex_payload_key com.android.devicelock.apex="${device_keys}"/com.android.devicelock.pem \
      --extra_apex_payload_key com.android.extservices.apex="${device_keys}"/com.android.extservices.pem \
      --extra_apex_payload_key com.android.graphics.pdf.apex="${device_keys}"/com.android.graphics.pdf.pem \
      --extra_apex_payload_key com.android.hardware.biometrics.face.virtual.apex="${device_keys}"/com.android.hardware.biometrics.face.virtual.pem \
      --extra_apex_payload_key com.android.hardware.biometrics.fingerprint.virtual.apex="${device_keys}"/com.android.hardware.biometrics.fingerprint.virtual.pem \
      --extra_apex_payload_key com.android.hardware.boot.apex="${device_keys}"/com.android.hardware.boot.pem \
      --extra_apex_payload_key com.android.hardware.cas.apex="${device_keys}"/com.android.hardware.cas.pem \
      --extra_apex_payload_key com.android.hardware.wifi.apex="${device_keys}"/com.android.hardware.wifi.pem \
      --extra_apex_payload_key com.android.healthfitness.apex="${device_keys}"/com.android.healthfitness.pem \
      --extra_apex_payload_key com.android.hotspot2.osulogin.apex="${device_keys}"/com.android.hotspot2.osulogin.pem \
      --extra_apex_payload_key com.android.i18n.apex="${device_keys}"/com.android.i18n.pem \
      --extra_apex_payload_key com.android.ipsec.apex="${device_keys}"/com.android.ipsec.pem \
      --extra_apex_payload_key com.android.media.apex="${device_keys}"/com.android.media.pem \
      --extra_apex_payload_key com.android.media.swcodec.apex="${device_keys}"/com.android.media.swcodec.pem \
      --extra_apex_payload_key com.android.mediaprovider.apex="${device_keys}"/com.android.mediaprovider.pem \
      --extra_apex_payload_key com.android.nearby.halfsheet.apex="${device_keys}"/com.android.nearby.halfsheet.pem \
      --extra_apex_payload_key com.android.networkstack.tethering.apex="${device_keys}"/com.android.networkstack.tethering.pem \
      --extra_apex_payload_key com.android.neuralnetworks.apex="${device_keys}"/com.android.neuralnetworks.pem \
      --extra_apex_payload_key com.android.ondevicepersonalization.apex="${device_keys}"/com.android.ondevicepersonalization.pem \
      --extra_apex_payload_key com.android.os.statsd.apex="${device_keys}"/com.android.os.statsd.pem \
      --extra_apex_payload_key com.android.permission.apex="${device_keys}"/com.android.permission.pem \
      --extra_apex_payload_key com.android.resolv.apex="${device_keys}"/com.android.resolv.pem \
      --extra_apex_payload_key com.android.rkpd.apex="${device_keys}"/com.android.rkpd.pem \
      --extra_apex_payload_key com.android.runtime.apex="${device_keys}"/com.android.runtime.pem \
      --extra_apex_payload_key com.android.safetycenter.resources.apex="${device_keys}"/com.android.safetycenter.resources.pem \
      --extra_apex_payload_key com.android.scheduling.apex="${device_keys}"/com.android.scheduling.pem \
      --extra_apex_payload_key com.android.sdkext.apex="${device_keys}"/com.android.sdkext.pem \
      --extra_apex_payload_key com.android.support.apexer.apex="${device_keys}"/com.android.support.apexer.pem \
      --extra_apex_payload_key com.android.telephony.apex="${device_keys}"/com.android.telephony.pem \
      --extra_apex_payload_key com.android.telephonymodules.apex="${device_keys}"/com.android.telephonymodules.pem \
      --extra_apex_payload_key com.android.tethering.apex="${device_keys}"/com.android.tethering.pem \
      --extra_apex_payload_key com.android.tzdata.apex="${device_keys}"/com.android.tzdata.pem \
      --extra_apex_payload_key com.android.uwb.apex="${device_keys}"/com.android.uwb.pem \
      --extra_apex_payload_key com.android.uwb.resources.apex="${device_keys}"/com.android.uwb.resources.pem \
      --extra_apex_payload_key com.android.virt.apex="${device_keys}"/com.android.virt.pem \
      --extra_apex_payload_key com.android.vndk.current.apex="${device_keys}"/com.android.vndk.current.pem \
      --extra_apex_payload_key com.android.vndk.current.on_vendor.apex="${device_keys}"/com.android.vndk.current.on_vendor.pem \
      --extra_apex_payload_key com.android.wifi.apex="${device_keys}"/com.android.wifi.pem \
      --extra_apex_payload_key com.android.wifi.dialog.apex="${device_keys}"/com.android.wifi.dialog.pem \
      --extra_apex_payload_key com.android.wifi.resources.apex="${device_keys}"/com.android.wifi.resources.pem \
      --extra_apex_payload_key com.google.pixel.camera.hal.apex="${device_keys}"/com.google.pixel.camera.hal.pem \
      --extra_apex_payload_key com.google.pixel.vibrator.hal.apex="${device_keys}"/com.google.pixel.vibrator.hal.pem \
      --extra_apex_payload_key com.qorvo.uwb.apex="${device_keys}"/com.qorvo.uwb.pem \
      "${OUT}"/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip signed-target_files.zip

      # Package Files
      ota_from_target_files -k "${device_keys}"/releasekey --block --backup=true signed-target_files.zip signed-ota_update.zip
      mv signed-ota_update.zip "${out_dir}"/"${device}"/"${build_date}"/lineage-"${android_version_number}"-"${build_date}"-"${LINEAGE_BUILDTYPE,,}"-"${device}"-signed.zip
    else
      echo "INFO: Brunch combo: ${combo}"
      brunch "${combo}"
      mv out/target/product/"${device}"/lineage-*.zip "${out_dir}"/"${device}"/"${build_date}"
    fi

    for image in boot vendor_boot vendor_kernel_boot dtbo
    do
      if [[ "${sign_lineageos}" == "1" ]]
      then
        (unzip -p signed-target_files.zip IMAGES/${image}.img > "${out_dir}"/"${device}"/"${build_date}"/${image}.img || true)
        find "${out_dir}"/"${device}"/"${build_date}" -maxdepth 1 -name "*.img" -empty -delete
      else
        find "${OUT}"/obj/PACKAGING/target_files_intermediates -name "${image}.img" \
        -exec mv {} "${out_dir}"/"${device}"/"${build_date}"/${image}.img \; || true
      fi
    done
  elif grep -q "${android_platform}" <<< "grapheneos"
  then
    keys_password="KEYS_PASSWORD_${device^^}"

    echo "INFO: Building GrapheneOS-${android_version_number} for ${device}"

    # Determine latest stable tag
    grapheneos_latest_tag=$(curl -sL https://grapheneos.org/releases | xmllint --html --xpath "/html/body/main/nav/ul/li[5]/ul/li[1]/a/text()" - 2> /dev/null)
    if [[ "${grapheneos_tag,,}" == "latest" && "${grapheneos_latest_tag}" =~ ^[[:digit:]]{10}$ ]]
    then
      echo "INFO: GrapheneOS tag set to \"latest\", using latest stable tag: ${grapheneos_latest_tag}"
      grapheneos_tag=${grapheneos_latest_tag}
    elif [[ "${grapheneos_tag,,}" == "latest" && ! "${grapheneos_latest_tag}" =~ ^[[:digit:]]{10}$ ]]
    then
      echo "FATAL: GrapheneOS tag set to \"latest\", but latest stable tag was not found" && exit 1
    elif [[ ! "${grapheneos_latest_tag}" =~ ^[[:digit:]]{10}$ ]]
    then
      echo "WARN: GrapheneOS latest stable tag not found. If explicit latest tag was set, lunch command will be incorrect."
    fi

    # Sync GrapheneOS repo
    [[ -f /.dockerenv ]] && repo_safe_dir
    clean_repo
    if [[ -n "${grapheneos_tag}" && ! "${grapheneos_tag}" =~ ^dev$|^development$ ]]
    then
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/"${grapheneos_tag}"
      mkdir ~/.ssh 2> /dev/null || true
      curl -sL https://grapheneos.org/allowed_signers -o ~/.ssh/grapheneos_allowed_signers
      cd .repo/manifests
      git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
      git verify-tag "$(git describe)" || (echo "FATAL: GrapheneOS tag verification failed" && exit 1)
      cd - > /dev/null
    elif grep -q "${device}" <<< "comet komodo caiman tokay"
    then
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "${android_version_number}"-caimoto
    elif grep -q "${device}" <<< "redfin bramble"
    then
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "${android_version_number}"-redfin
    elif grep -q "${device}" <<< "coral flame"
    then
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "${android_version_number}"-coral
    elif grep -q "${device}" <<< "sunfish"
    then
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "${android_version_number}"
    else
      repo init -u https://github.com/GrapheneOS/platform_manifest.git -b "${android_version_number}"
    fi
    sync_repo
    source build/envsetup.sh > /dev/null
    [[ -n "${grapheneos_tag}" ]] && export BUILD_NUMBER=${grapheneos_tag}
    echo "BUILD_DATETIME=${BUILD_DATETIME} BUILD_NUMBER=${BUILD_NUMBER}"

    mkdir -p "${out_dir}"/"${device}"/"${BUILD_NUMBER}" 2> /dev/null || true

    if [[ -d "${vanadium_dir}/src/out/Default/apks/release" ]]
    then
      for trichrome in TrichromeChrome TrichromeLibrary TrichromeWebView
      do
        cp -f "${vanadium_dir}"/src/out/Default/apks/release/${trichrome}.apk external/vanadium/prebuilt/arm64
      done
      cp -f "${vanadium_dir}"/src/out/Default/apks/release/VanadiumConfig.apk external/vanadium/prebuilt
    fi

    # Build kernel
    [[ -z "${kernel_dir}" ]] && echo "FATAL: GrapheneOS Kernel directory missing" && usage
    cd "${kernel_dir}"
    clean_repo
    # 9th gen
    if grep -q "${device}" <<< "comet komodo caiman tokay"
    then
      grep -q "${device}" <<< "komodo caiman tokay" && device_family=caimoto || device_family=${device}
      mkdir "${device_family}" 2> /dev/null || true
      cd "${device_family}"
      [[ -f /.dockerenv ]] && repo_safe_dir
      repo init -u https://github.com/GrapheneOS/kernel_manifest-zumapro.git -b "${android_version_number}"-caimoto
      sync_repo
      ./build_"${device_family}".sh --config=use_source_tree_aosp --config=no_download_gki --lto=full
      cp -rf out/"${device_family}"/dist/* "${android_top}"/device/google/"${device_family}"-kernels/6.1/24D1
    # 8th gen
    elif grep -q "${device}" <<< "husky shiba akita"
    then
      grep -q "${device}" <<< "husky shiba" && device_family=shusky || device_family=${device}
      mkdir "${device_family}" 2> /dev/null || true
      cd "${device_family}"
      [[ -f /.dockerenv ]] && repo_safe_dir
      repo init -u https://github.com/GrapheneOS/kernel_manifest-zuma.git -b "${android_version_number}"
      sync_repo
      ./build_"${device_family}".sh --config=use_source_tree_aosp --config=no_download_gki --lto=full
      cp -rf out/"${device_family}"/dist/* "${android_top}"/device/google/"${device_family}"-kernel
    # 7th and 6th gen (same manifest)
    elif grep -q "${device}" <<< "cheetah panther lynx tangorpro felix raven oriole bluejay"
    then
      if grep -q "${device}" <<< "cheetah panther"
      then
        device_family=pantah
      elif grep -q "${device}" <<< "raven oriole"
      then
        device_family=raviole
      else
        device_family=${device}
      fi
      mkdir "${device_family}" 2> /dev/null || true
      cd "${device_family}"
      [[ -f /.dockerenv ]] && repo_safe_dir
      repo init -u https://github.com/GrapheneOS/kernel_manifest-gs.git -b "${android_version_number}"
      sync_repo
      if [[ ${device_family} == "pantah" ]]
      then
        BUILD_AOSP_KERNEL=1 LTO=full ./build_cloudripper.sh
      elif [[ ${device_family} == "raviole" ]]
      then
        BUILD_AOSP_KERNEL=1 LTO=full ./build_slider.sh
      else
        BUILD_AOSP_KERNEL=1 LTO=full ./build_"${device_family}".sh
      fi
      cp -rf out/mixed/dist/* "${android_top}"/device/google/"${device_family}"-kernel
    # 5th gen
    elif grep -q "${device}" <<< "redfin bramble"
    then
      mkdir redbull 2> /dev/null || true
      cd redbull
      [[ -f /.dockerenv ]] && repo_safe_dir
      repo init -u https://github.com/GrapheneOS/kernel_manifest-redbull.git -b "${android_version_number}"
      sync_repo
      BUILD_CONFIG=private/msm-google/build.config.redbull.vintf build/build.sh
      cp -rf out/android-msm-pixel-4.19/dist/* "${android_top}"/device/google/redbull-kernel
      cp -rf out/android-msm-pixel-4.19/dist/* "${android_top}"/device/google/redbull-kernel/vintf
    # 4th gen
    elif grep -q "${device}" <<< "coral flame sunfish"
    then
      grep -q "${device}" <<< "coral flame" && device_family=coral || device_family=${device}
      mkdir "${device_family}" 2> /dev/null || true
      cd "${device_family}"
      [[ -f /.dockerenv ]] && repo_safe_dir
      repo init -u https://github.com/GrapheneOS/kernel_manifest-coral.git -b "${android_version_number}"
      sync_repo
      [[ ${device_family} == "coral" ]] && build_config=floral || build_config=${device_family}
      KBUILD_BUILD_VERSION=1 KBUILD_BUILD_USER=build-user \
      KBUILD_BUILD_HOST=build-host KBUILD_BUILD_TIMESTAMP=$(TZ=UTC date) \
      BUILD_CONFIG=private/msm-google/build.config.${build_config} build/build.sh
      cp -rf out/android-msm-pixel-4.14/dist/* "${android_top}"/device/google/"${device_family}"-kernel
    fi
    cd "${android_top}"

    # Extract vendor files
    if [[ "${yarn}" == "1" ]]
    then
      echo "Exracting vendor files"
      yarnpkg install --cwd vendor/adevtool/
      lunch sdk_phone64_x86_64-cur-user
      m aapt2
      vendor/adevtool/bin/run generate-all -d "${device}"
    fi
    [[ ! -d vendor/google_devices/${device} ]] && echo "FATAL: vendor/google_devices/${device} missing" && exit 1

    # Apply User Scripts
    [[ -n "${user_scripts}" ]] && apply_user_scripts

    # Initialize device build
    tag_regex="${grapheneos_latest_tag}|^dev$|^development$"
    if [[ "${grapheneos_tag,,}" =~ ${tag_regex} || -z "${grapheneos_tag}" ]] && ! grep -q "${device}" <<< "coral flame sunfish"
    then
      build_id=$(grep "(BUILD_ID)" vendor/google_devices/"${device}"/"${device}".mk | head -n1 | cut -d, -f2 | tr -d \))
      export build_id
      export release_id=${build_id%%.*}
      combo="${device}-${release_id,,}-${variant}"
    else
      combo="${device}-${variant}"
    fi
    echo "INFO: Lunch combo: ${combo}"
    lunch "${combo}"

    # Verify official build release url updated
    if [[ "${OFFICIAL_BUILD}" == "true" ]]
    then
      if grep -q "releases.grapheneos.org" packages/apps/Updater/res/values/config.xml
      then
        echo "FATAL: Official build detected. Update server URL must be changed from default"
        usage
      fi
    fi

    # Build
    if grep -q "${device}" <<< "husky shiba akita cheetah panther lynx tangorpro felix raven oriole bluejay"
    then
      m vendorbootimage
    fi
    if grep -q "${device}" <<< "husky shiba akita cheetah panther lynx tangorpro felix"
    then
      m vendorkernelbootimage
    fi
    m target-files-package
    m otatools-package
    script/finalize.sh
    echo -e "${!keys_password}\n${!keys_password}" | script/generate-release.sh "${device}" "${BUILD_NUMBER}"
    if [[ "${out_dir}" != "${ANDROID_BUILD_TOP}/releases" ]]
    then
      grep -q "${device}" <<< "coral flame sunfish" && installer=factory || installer=install
      for pkg in ${installer} ota_update
      do
        mv releases/"${BUILD_NUMBER}"/release-"${device}"-"${BUILD_NUMBER}"/"${device}"-"${pkg}"-"${BUILD_NUMBER}".zip \
        "${out_dir}"/"${device}"/"${BUILD_NUMBER}"/"${device}"-"${pkg}"-"${BUILD_NUMBER}".zip
      done
      mv releases/"${BUILD_NUMBER}"/release-"${device}"-"${BUILD_NUMBER}"/"${device}"-"${installer}"-"${BUILD_NUMBER}".zip.sig \
      "${out_dir}"/"${device}"/"${BUILD_NUMBER}"/"${device}"-"${installer}"-"${BUILD_NUMBER}".zip.sig
    fi
  else
    echo "FATAL: Only GrapheneOS and LineageOS are supported"
    exit 1
  fi

  # Clean Up
  m clean
  [[ -L "keys/${device}" ]] && rm -rf keys/"${device}"
  echo "INFO: Build for ${device} finished"
  unset device
done
