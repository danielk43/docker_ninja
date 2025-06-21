#!/usr/bin/env bash

# shellcheck disable=SC2015
# shellcheck disable=SC2046
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2206
# shellcheck source=/dev/null

set -eo pipefail

# Initialize Device Builds
for device in ${devices}
do
  export device

  # Set OS Major Version  # https://calyxos.org/install
  calyxos6_devices=(redfin bramble barbet oriole raven bluejay panther cheetah lynx tangorpro felix shiba \
                   husky akita tokay caiman komodo comet tegu devon hawao rhode fogos fogo bangkk FP4 FP5)
  for calyxos6_device in "${calyxos6_devices[@]}"
  do
    [[ "${device}" == "${calyxos6_device}" ]] && export calyx_version_major="6" && break || true
  done
  [[ -z "${calyx_version_major}" ]] && echo "FATAL: Device ${device} not supported by CalyxOS" && usage
  echo "INFO: Building CalyxOS ${calyx_version_major} for ${device}"

  # Reset COS repo
  repo_safe_dir
  git_clean_repo -c -d "${PWD}"

  # Set Variables
  export device_out="${out_dir}"/"${device}"/"${build_date}"
  export otatools_dir="${android_top}"/out/host/linux-x86
  export latest_tag_cmd="https://gitlab.com/api/v4/projects/8459465/repository/tags \
                         | jq -r '[.[] | select(.name | match(\"^${calyx_version_major}.\")).name][0]'"
  export RELAX_USES_LIBRARY_CHECK="true"

  # Sync CalyxOS repo
  repo_init_ref
  [[ "${release_tag}" =~ ^dev|^$ ]] && release_tag="android${android_version_number%.*}"
  if [[ "${release_tag}" =~ ^${calyx_version_major}. ]]
  then
    repo init -u https://gitlab.com/CalyxOS/platform_manifest -b refs/tags/"${release_tag}" --git-lfs
  else
    repo init -u https://gitlab.com/CalyxOS/platform_manifest -b "${release_tag}" --git-lfs
  fi
  repo_safe_dir
  sync_repo
  source build/envsetup.sh

  # Get vendor image
  if [[ "$persist_vendor" == "0" ]]
  then
    echo "INFO: Extracting vendor files"
    rm -rf vendor/google/*
    calyx/scripts/pixel/device.sh "${device}"
  fi

  # Build OS
  combo="${device} ${variant}"
  echo "INFO: Breakfast combo: ${combo}"
  breakfast ${combo}

  # Create outfile directory
  [[ -z "${out_dir}" ]] && export out_dir="${ANDROID_BUILD_TOP}/releases"
  rm -rf "${device_out}"
  mkdir -p "${device_out}" 2>/dev/null
 
  print_env

  if [[ "${sign_build}" == "1" ]]
  then
    [[ -z "${keys_dir}" ]] && echo "Keys Dir is required if signing build" && usage
    export BUILD_NUMBER="${variant}.signed.${build_date}"
    common_keys="${keys_dir}/common"
    device_keys="${keys_dir}/${device}"

    echo "INFO: Building otatools packages"
    m otatools-package

    # Generate signing keys
    if [[ ! -d "${common_keys}" || ! -d "${device_keys}" ]]
    then
      cd "${otatools_dir}"
      [[ ! -d "${common_keys}" ]] && yes "" | "${android_top}"/vendor/calyx/scripts/mkcommonkeys.sh "${common_keys}" "${android_dname}" || true
      [[ ! -d "${device_keys}" ]] && yes "" | "${android_top}"/vendor/calyx/scripts/mkkeys.sh "${device_keys}" "${android_dname}" || true
      cd "${android_top}"
    fi

    # Link keys (containerized link will not be found on host)
    if [[ "${keys_dir}" != "${otatools_dir}/keys" ]]
    then
      mkdir -p "${otatools_dir}"/keys "${android_top}"/keys 2>/dev/null || true
      ln -s "${common_keys}" "${otatools_dir}"/keys 2>/dev/null || echo "WARN: Linking common signing keys in out/ failed"
      ln -s "${device_keys}" "${android_top}"/keys 2>/dev/null || echo "WARN: Linking ${device} signing keys in keys/ failed"
      ln -s "${device_keys}" "${otatools_dir}"/keys 2>/dev/null || echo "WARN: Linking ${device} signing keys in out/ failed"
    fi
  fi

  # Apply User Scripts
  [[ -n "${user_scripts}" ]] && apply_user_scripts

  # Set build type
  [[ -n "${build_type}" ]] && sed -i "s/PRODUCT_VERSION_EXTRA +=.*/PRODUCT_VERSION_EXTRA += -${build_type}/" vendor/calyx/config/version.mk

  # Verify official build release url updated
  if [[ "${OFFICIAL_BUILD}" == "true" ]]
  then
    if grep -q "release.calyxinstitute.org" packages/apps/Updater/res/values/config.xml
    then
      echo "FATAL: Official build detected. Update server URL must be changed from default"
      usage
    fi
  fi

  if [[ "${sign_build}" == "1" ]]
  then
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
if [[ "${clean_repo}" == "1" ]]
then
  git_clean_repo -cg -d "${android_top}"
fi

exit 0

