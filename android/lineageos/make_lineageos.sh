#!/usr/bin/env bash

# shellcheck disable=SC2034
# shellcheck disable=SC2046
# shellcheck disable=SC2154
# shellcheck source=/dev/null

set -eo pipefail

. "${build_path}"/initialize_"${android_platform}".sh

[[ -n "${gms_makefile}" ]] && export WITH_GMS="true" GMS_MAKEFILE="${gms_makefile}"

# Device Build
devices=$(printf %s "${device_list,,}" | sed -e "s/[[:punct:]]\+/ /g")
echo "INFO: Device list: ${devices}"
for device in ${devices}
do
  export device
  echo "INFO: Building LineageOS-${android_version_number} for ${device}"

  # Setup key vars
  keys_password="KEYS_PASSWORD_${device^^}"
  device_keys="${keys_dir}/${device}"

  # Link keys (containerized link will not be found on host)
  if [[ "${keys_dir}" != "${android_top}/keys" ]]
  then
    mkdir keys 2>/dev/null || true
    if [[ ! -d "${device_keys}" ]]
    then
      mkdir "${device_keys}" 2>/dev/null || true
    fi
    ln -s "${device_keys}" "${android_top}"/keys 2>/dev/null || echo "WARN: Linking ${device} signing keys failed"
  fi

  # Generate signing keys
  [[ "${sign_lineageos}" == "1" && -z "${keys_dir}" ]] && echo "Keys Dir is required if signing build" && usage
  [[ "${sign_lineageos}" == "1" ]] && make_lineageos_keys

  # Set build type
  [[ -n "${build_type}" ]] && export LINEAGE_BUILDTYPE="${build_type}"
  [[ -n "${LINEAGE_BUILDTYPE}" ]] && sed -i '/Filter out random types/,+5d' vendor/lineage/config/version.mk

  mkdir -p "${out_dir}"/"${device}"/"${build_date}" 2>/dev/null || true

  # Sync LOS repo
  [[ -f /.dockerenv ]] && repo_safe_dir
  clean_repo
  repo init -u https://github.com/LineageOS/android.git -b lineage-"${android_version_number}" --git-lfs
  [[ "$roomservice" == "1" ]] && rm -f .repo/local_manifests/roomservice.xml
  [[ -f /.dockerenv ]] && repo_safe_dir
  sync_repo
  source build/envsetup.sh

  (( ${android_version_number%%.*} < 19 )) && echo "FATAL: Only LineageOS 19 or higher supported" && usage

  # Apply User Scripts
  [[ -n "${user_scripts}" ]] && apply_user_scripts

  # Verify official build release url updated
  if [[ "${OFFICIAL_BUILD}" == "true" ]]
  then
    if grep -q "download.lineageos.org/api" packages/apps/Updater/app/src/main/res/values/strings.xml 
    then
      echo "FATAL: Official build detected. Update server URL must be changed from default"
      usage
    fi
  fi

  if (( "${android_version_number%%.*}" > 20 ))
  then
    target=$(grep target vendor/lineage/vars/aosp_target_release | cut -d= -f2)
    combo=lineage_"${device}-${target}-${variant}"
  else
    combo=lineage_"${device}-${variant}"
  fi

  print_env

  # Build OS
  if [[ "${sign_lineageos}" == "1" ]]
  then
    echo "INFO: Breakfast combo: ${combo}"
    breakfast "${combo}"
    m target-files-package otatools

    # Sign build
    sign_target_files_apks -o -d "${device_keys}" $(extra_apks_args) \
    "${OUT}"/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip signed-target_files.zip

    # Package Files
    ota_from_target_files -k "${device_keys}"/releasekey --block --backup=true signed-target_files.zip signed-ota_update.zip
  else
    echo "INFO: Brunch combo: ${combo}"
    brunch "${combo}"
  fi

  # Create outfile directory
  [[ -z "${out_dir}" ]] && export out_dir="${ANDROID_BUILD_TOP}/releases"
  device_out="${out_dir}"/"${device}"/"${build_date}"
  rm -rf "${device_out}"
  mkdir -p "${device_out}" 2>/dev/null

  # Move signed build to out dir
  if [[ "${sign_lineageos}" == "1" ]]
  then
    mv signed-ota_update.zip "${device_out}"/lineage-"${android_version_number}"-"${build_date}"-"${LINEAGE_BUILDTYPE,,}"-"${device}"-signed.zip
    find "${device_out}" -maxdepth 1 -name "*.img" -empty -delete
  else
    mv out/target/product/"${device}"/lineage-*.zip "${device_out}"
  fi

  # Copy install images to device out
  for img in boot vendor_boot vendor_kernel_boot dtbo
  do
    if [[ "${sign_lineageos}" == "1" ]]
    then
      unzip -p signed-target_files.zip IMAGES/${img}.img > "${device_out}"/${img}.img || true
    else
      find "${OUT}"/obj/PACKAGING/target_files_intermediates -name "${img}.img" \
      -exec mv {} "${device_out}"/${img}.img \; || true
    fi
  done

  # Remove device-specific settings
  [[ -L "keys/${device}" ]] && rm -f "keys/${device}"
  echo "INFO: Build for ${device} finished"
  unset ANDROID_PW_FILE device device_keys keys_password
done

# Deep clean android and chromium src
[[ "${clean_repo}" == "1" ]] && . "${BUILD_HOME}"/git_deep_clean.sh -cg -d "${android_top}"

exit 0

