#!/usr/bin/env bash

# shellcheck disable=SC2015
# shellcheck disable=SC2046
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2206
# shellcheck source=/dev/null

set -eo pipefail

. "${build_path}"/initialize_"${android_platform}".sh

# Device Build
devices=$(printf %s "${device_list}" | sed -e "s/[[:punct:]]\+/ /g")
echo "INFO: Device list: ${devices}"
for device in ${devices}
do
  export device

  # Set OS Major Version
  if grep -q "${device}" <<< "rhode hawao devon axolotl FP4 FP5 blueline crosshatch sargo bonito flame coral sunfish barbet bramble redfin"
  then
    export calyx_version_major="5"
  elif grep -q "${device}" <<< "oriole raven bluejay panther cheetah lynx tangorpro felix akita husky shiba caiman comet komodo tokay"
  then
    export calyx_version_major="6"
  else
    echo "FATAL: Device ${device} not supported by CalyxOS" && usage
  fi

  echo "INFO: Building CalyxOS ${calyx_version_major} for ${device}"

  # Reset COS repo
  [[ -f /.dockerenv ]] && repo_safe_dir
  clean_repo

  # Set Variables
  export device_out="${out_dir}"/"${device}"/"${build_date}"
  export otatools_dir="${android_top}"/out/host/linux-x86
  export latest_tag_cmd="https://gitlab.com/api/v4/projects/8459465/repository/tags \
                         | jq -r '[.[] | select(.name | match(\"^${calyx_version_major}.\")).name][0]'"
  export RELAX_USES_LIBRARY_CHECK="true"

  # Sync CalyxOS repo
  repo_init_ref
  [[ "${manifest_tag}" =~ ^dev|^$ ]] && manifest_tag="android${android_version_number%.*}"
  if [[ "${manifest_tag}" =~ ^${calyx_version_major}. ]]
  then
    repo init -u https://gitlab.com/CalyxOS/platform_manifest -b refs/tags/"${manifest_tag}" --git-lfs
  else
    repo init -u https://gitlab.com/CalyxOS/platform_manifest -b "${manifest_tag}" --git-lfs
  fi
  [[ -f /.dockerenv ]] && repo_safe_dir
  sync_repo
  source build/envsetup.sh

  # Get vendor image
  build_id=$(grep build_id calyx/scripts/vars/"${device}" | cut -d\" -f2)
  if ! grep -q "${build_id}" vendor/google/"${device}"/build_id.txt 2>/dev/null
  then
    calyx/scripts/pixel/device.sh "${device}"
  fi
  combo="${device} ${variant}"

  # Apply User Scripts
  [[ -n "${user_scripts}" ]] && apply_user_scripts

  # Set build type
  [[ -n "${build_type}" ]] && sed -i "s/PRODUCT_VERSION_EXTRA +=.*/PRODUCT_VERSION_EXTRA += -${build_type^^}/" vendor/calyx/config/version.mk

  # Verify official build release url updated
  if [[ "${OFFICIAL_BUILD}" == "true" ]]
  then
    if grep -q "release.calyxinstitute.org" packages/apps/Updater/res/values/config.xml
    then
      echo "FATAL: Official build detected. Update server URL must be changed from default"
      usage
    fi
  fi

  # Build OS
  echo "INFO: Breakfast combo: ${combo}"
  breakfast ${combo}

  # Create outfile directory
  [[ -z "${out_dir}" ]] && export out_dir="${ANDROID_BUILD_TOP}/releases"
  rm -rf "${device_out}"
  mkdir -p "${device_out}" 2>/dev/null
 
  print_env

  if [[ "${sign_build}" == "1" ]]
  then
    export BUILD_NUMBER="${variant}.signed.${build_date}"

    # Generate signing keys
    [[ "${sign_build}" == "1" && -z "${keys_dir}" ]] && echo "Keys Dir is required if signing build" && usage
    if [[ "${sign_build}" == "1" ]]
    then
      echo "INFO: Building otatools packages"
      mkdir release 2>/dev/null || true
      m otatools-package
      common_keys="${keys_dir}/common"
      device_keys="${keys_dir}/${device}"
      if [[ ! -d "${common_keys}" || ! -d "${device_keys}" ]]
      then
        m otatools-keys-package
        cd "${otatools_dir}"
        [[ ! -d "${common_keys}" ]] && yes "" | "${android_top}"/vendor/calyx/scripts/mkcommonkeys.sh "${common_keys}" "${android_dname}" || true
        [[ ! -d "${device_keys}" ]] && yes "" | "${android_top}"/vendor/calyx/scripts/mkkeys.sh "${device_keys}" "${android_dname}" || true
        cd "${android_top}"
      fi
    fi

    # Link keys (containerized link will not be found on host)
    if [[ "${keys_dir}" != "${otatools_dir}/keys" ]]
    then
      mkdir -p "${otatools_dir}"/keys "${android_top}"/keys 2>/dev/null || true
      ln -s "${common_keys}" "${otatools_dir}"/keys 2>/dev/null || echo "WARN: Linking common signing keys in out/ failed"
      ln -s "${device_keys}" "${android_top}"/keys 2>/dev/null || echo "WARN: Linking ${device} signing keys in keys/ failed"
      ln -s "${device_keys}" "${otatools_dir}"/keys 2>/dev/null || echo "WARN: Linking ${device} signing keys in out/ failed"
    fi

    m target-files-package

    # Sign and Release build
    ln -s "${android_top}"/build "${otatools_dir}"/build
    cp -f "${OUT}"/obj/PACKAGING/target_files_intermediates/calyx_"${device}"-target_files*.zip "${otatools_dir}"
    cd "${otatools_dir}"
    bash "${android_top}"/vendor/calyx/scripts/release.sh "${device}" calyx_"${device}"-target_files*.zip
    python "${android_top}"/vendor/calyx/scripts/generate_metadata.py out/release-"${device}"-"${BUILD_NUMBER}"/"${device}"-ota_update-"${BUILD_NUMBER}".zip
    mv "${device}"-testing out/release-"${device}"-"${BUILD_NUMBER}"
    mv -f out/release-"${device}"-"${BUILD_NUMBER}" "${device_out}"
    cd "${android_top}"
  else
    m
    mkdir -p "${device_out}"/flashall 2>/dev/null || true
    cp -f out/target/product/"${device}"/{*.img,android-info.txt} "${device_out}"/flashall
  fi

  # Remove build-specific settings
  echo "INFO: Build for ${device} finished"
  [[ -L "keys/${device}" ]] && rm -f "keys/${device}"
  unset device device_keys
done

# Deep clean android and chromium src
[[ "${clean_repo}" == "1" ]] && . "${BUILD_HOME}"/git_deep_clean.sh -cg -d "${android_top}"

exit 0

