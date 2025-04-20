#!/usr/bin/env bash

# shellcheck disable=SC2046
# shellcheck disable=SC2154
# shellcheck source=/dev/null

set -eo pipefail

# Initialize signing keys
. "${build_path}"/"${android_platform}"_keys.sh

# Build Vanadium once, outside of devices loop
if [[ -n "${VANADIUM_PASSWORD}" && -d ${chromium_dir} ]]
then
  cd "${chromium_dir}"
  [[ -f "args.gn" ]] || git clone https://github.com/GrapheneOS/Vanadium.git .
  clean_repo
  git config --global --add safe.directory "${chromium_dir}"
  git reset --hard && git clean -ffd
  git fetch --all --force --tags --prune --prune-tags
  git checkout main # TODO: add tags checkout functionality
  git pull --rebase -X ours "$(git remote)" "$(git branch --show-current)" # rebase on tags also? git describe --exact-match --tags
  vanadium_current_version=$(grep android_default_version_name args.gn | cut -d\" -f2)

  if [[ ! -f vanadium.keystore ]]
  then
    echo -e "${VANADIUM_PASSWORD}\n${VANADIUM_PASSWORD}" | \
    keytool -genkey -v -keystore vanadium.keystore -storetype pkcs12 -alias vanadium \
    -keyalg RSA -keysize 4096 -sigalg SHA512withRSA -validity 10000 -dname "${chromium_dname}"
  fi

  keystore_sha=$(echo "${VANADIUM_PASSWORD}" | keytool -export-cert -alias vanadium -keystore vanadium.keystore | sha256sum | awk '{print $1}')
  sed -i "s/certdigest.*/certdigest = \"${keystore_sha}\"/" args.gn

  [[ ! -d src ]] && fetch --nohooks android
  cd src
  git config --global --add safe.directory "${PWD}" \
  && for repository in $(dirname $(find . -type d -name .git -printf "%P\n"))
  do
    git config --global --add safe.directory "${PWD}"/"${repository}"
  done
  rm -rf .git/*-apply && git_reset_clean &> /dev/null
  git submodule foreach "git reset --hard; git clean -ffdx" &> /dev/null || true
  git fetch --all --force --tags --prune --prune-tags
  git checkout --force "${vanadium_current_version}"
  git am --whitespace=nowarn --keep-non-patch "${chromium_dir}"/patches/*.patch
  cd "${chromium_dir}" && gclient sync -D --with_branch_heads --with_tags --jobs "${sync_jobs}" && cd src
  mkdir -p out/Default
  cp -fp "${chromium_dir}"/args.gn out/Default
  gn gen out/Default
  gn args out/Default --list > out/Default/gn_list

  chrt -b 0 autoninja -C out/Default trichrome_webview_64_32_apk \
  trichrome_chrome_64_32_apk trichrome_library_64_32_apk vanadium_config_apk

  echo "${VANADIUM_PASSWORD}" | "${chromium_dir}"/generate-release out
  cd "${android_top}"
fi

# Initialize Device Build
devices=$(printf %s "${device_list,,}" | sed -e "s/[[:punct:]]\+/ /g")
echo "INFO: Device list: ${devices}"
for device in ${devices}
do
  export device
  echo "INFO: Building GrapheneOS-${android_version_number} for ${device}"

  # Generate signing keys
  keys_password="KEYS_PASSWORD_${device^^}"
  device_keys="${keys_dir}/${device}"
  [[ -z "${keys_dir}" ]] && echo "Keys Dir is required for signing build" && usage
  make_grapheneos_keys

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

  # Reset GOS repo
  repo_safe_dir
  clean_repo

  # Sync GrapheneOS repo
  export latest_tag_cmd="https://grapheneos.org/releases | xmllint --html --xpath \
                        '/html/body/main/nav/ul/li[4]/ul/li[1]/a/text()' - 2> /dev/null"
  repo_init_ref
  if [[ ! "${release_tag}" =~ ^dev|^$ ]]
  then
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/"${release_tag}"
    mkdir ~/.ssh 2>/dev/null || true
    curl -sL https://grapheneos.org/allowed_signers -o ~/.ssh/grapheneos_allowed_signers
    cd .repo/manifests
    git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
    git verify-tag "$(git describe)" || (echo "FATAL: GrapheneOS tag verification failed" && exit 1)
    cd - > /dev/null
  elif grep -q "${device}" <<< "coral flame"
  then
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b 13-coral
  elif grep -q "${device}" <<< "sunfish"
  then
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b 13
  elif grep -q "${device}" <<< "redfin bramble"
  then
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b 14-redfin
  elif grep -q "${device}" <<< "barbet"
  then
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b 14
  else
    repo init -u https://github.com/GrapheneOS/platform_manifest.git -b 15-qpr2
  fi
  repo_safe_dir
  sync_repo
  source build/envsetup.sh >/dev/null

  [[ -n "${release_latest_tag}" ]] && export BUILD_NUMBER=${release_tag}
  echo "BUILD_DATETIME=${BUILD_DATETIME} BUILD_NUMBER=${BUILD_NUMBER}"

  if [[ -d "${chromium_dir}/src/out/Default/apks/release" ]]
  then
    for trichrome in TrichromeChrome TrichromeLibrary TrichromeWebView
    do
      cp -f "${chromium_dir}"/src/out/Default/apks/release/"${trichrome}".apk external/vanadium/prebuilt/arm64
    done
    cp -f "${chromium_dir}"/src/out/Default/apks/release/VanadiumConfig.apk external/vanadium/prebuilt
  fi

  # Build kernel
  [[ -z "${kernel_dir}" ]] && echo "FATAL: GrapheneOS Kernel directory missing" && usage
  cd "${kernel_dir}"
  # 6th through 9th gen
  if grep -q "${device}" <<< "tegu comet komodo caiman tokay husky shiba akita cheetah panther lynx tangorpro felix raven oriole bluejay"
  then
    kernel=pixel
    if grep -q "${device}" <<< "komodo caiman tokay"
    then
      codename=caimoto
    elif grep -q "${device}" <<< "husky shiba"
    then
      codename=shusky
    elif grep -q "${device}" <<< "cheetah panther"
    then
      codename=pantah
    elif grep -q "${device}" <<< "raven oriole"
    then
      codename=raviole
    else
      codename=${device}
    fi
    mkdir "${kernel}" 2>/dev/null || true
    cd "${kernel}"
    repo_safe_dir
    repo init -u https://github.com/GrapheneOS/kernel_manifest-"${kernel}".git -b 15-qpr2
    clean_repo
    sync_repo
    ./build_"${codename}".sh --config=no_download_gki --config=no_download_gki_fips140 --lto=full
    cp -rf out/"${codename}"/dist/* "${android_top}"/device/google/"${codename}"-kernels/**/*
  # 5th gen
  elif grep -q "${device}" <<< "redfin barbet bramble"
  then
    codename=redbull kernel=redbull
    mkdir "${kernel}" 2>/dev/null || true
    cd "${kernel}"
    repo_safe_dir
    repo init -u https://github.com/GrapheneOS/kernel_manifest-"${kernel}".git -b 15
    clean_repo
    sync_repo
    BUILD_CONFIG=private/msm-google/build.config."${codename}".vintf build/build.sh
    rm -rf "${android_top}"/device/google/"${codename}"-kernel
    mkdir -p "${android_top}"/device/google/"${codename}"-kernel/vintf
    if [[ "${variant}" =~ ^(eng|userdebug)$ ]]
    then
      cp -rf out/android-msm-pixel-4.19/dist/* "${android_top}"/device/google/"${codename}"-kernel
    elif [[ "${variant}" == "user" ]]
    then
      cp -rf out/android-msm-pixel-4.19/dist/* "${android_top}"/device/google/"${codename}"-kernel/vintf
    fi
  # 4th gen
  elif grep -q "${device}" <<< "sunfish coral flame"
  then
    kernel_repo=coral
    if grep -q "${device}" <<< "coral flame"
    then
      codename=floral kernel=coral
    else
      codename=${device} kernel=${device}
    fi
    mkdir "${kernel_repo}" 2>/dev/null || true
    cd "${kernel_repo}"
    repo_safe_dir
    repo init -u https://github.com/GrapheneOS/kernel_manifest-"${kernel_repo}".git -b 13
    clean_repo
    sync_repo
    KBUILD_BUILD_VERSION=1 KBUILD_BUILD_USER=build-user KBUILD_BUILD_HOST=build-host KBUILD_BUILD_TIMESTAMP="Thu 01 Jan 1970 12:00:00 AM UTC" \
    BUILD_CONFIG=private/msm-google/build.config."${codename}" build/build.sh
    rm -rf "${android_top}"/device/google/"${kernel}"-kernel
    mkdir "${android_top}"/device/google/"${kernel}"-kernel
    cp -rf out/android-msm-pixel-4.14/dist/* "${android_top}"/device/google/"${kernel}"-kernel
  fi
  cd "${android_top}"

  # Extract vendor files
  if [[ "${persist_vendor}" == "0" ]]
  then
    echo "INFO: Extracting vendor files"
    rm -rf vendor/adevtool/node_modules
    yarnpkg install --cwd vendor/adevtool
    lunch sdk_phone64_x86_64-cur-user
    m aapt2
    rm -rf vendor/google_devices/*
    vendor/adevtool/bin/run generate-all -d "${device}"
  fi
  [[ ! -d vendor/google_devices/${device} ]] && echo "FATAL: vendor/google_devices/${device} missing" && usage

  # Apply User Scripts
  [[ -n "${user_scripts}" ]] && apply_user_scripts

  # Verify official build release url updated
  if [[ "${OFFICIAL_BUILD}" == "true" ]]
  then
    if grep -q "releases.grapheneos.org" packages/apps/Updater/res/values/config.xml
    then
      echo "FATAL: Official build detected. Update server URL must be changed from default"
      usage
    fi
  fi

  # Initialize device build
  tag_regex="${grapheneos_latest_tag}|^dev$|^development$"
  if [[ "${grapheneos_tag,,}" =~ ${tag_regex} || -z "${grapheneos_tag}" ]] && ! grep -q "${device}" <<< "coral flame sunfish"
  then
    build_id=$(grep "(BUILD_ID)" vendor/google_devices/"${device}"/"${device}".mk | head -n1 | cut -d, -f2 | tr -d \))
    export build_id
    export release_id=${build_id%%.*}
    cp -f build/release/flag_values/cur/* build/release/flag_values/"${release_id,,}"
    combo="${device}-${release_id,,}-${variant}"
  else
    combo="${device}-${variant}"
  fi

  print_env

  echo "INFO: Lunch combo: ${combo}"
  lunch "${combo}"

  # Build
  if grep -q "${device}" <<< "tegu comet komodo caimen tokay husky shiba akita cheetah panther lynx tangorpro felix raven oriole bluejay"
  then
    m vendorbootimage
  fi
  if grep -q "${device}" <<< "tegu comet komodo caimen tokay husky shiba akita cheetah panther lynx tangorpro felix"
  then
    m vendorkernelbootimage
  fi
  m target-files-package
  m otatools-package
  script/finalize.sh
  expect << EOF
    set timeout -1
    spawn script/generate-release.sh "${device}" "${BUILD_NUMBER}"
    expect "Enter key passphrase"
    send -- "${!keys_password}\r"
    expect "Enter passphrase"
    send -- "${!keys_password}\r"
    expect eof
EOF

  # Create outfile directory
  [[ -z "${out_dir}" ]] && export out_dir="${ANDROID_BUILD_TOP}/releases"
  [[ "${out_dir}" != "${ANDROID_BUILD_TOP}/releases" ]] && \
  device_out="${out_dir}"/"${device}"/"${BUILD_NUMBER}"
  rm -rf "${device_out}"
  mkdir -p "${device_out}" 2>/dev/null

  # Copy artifacts to out dir
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

  # Remove device-specific settings
  [[ -L "keys/${device}" ]] && rm -f "keys/${device}"
  echo "INFO: Build for ${device} finished"
  unset device device_keys keys_password
done

# Deep clean android and chromium src
[[ "${clean_repo}" == "1" ]] && . "${BUILD_HOME}"/git_deep_clean.sh -cg -d "${android_top}"
[[ "${clean_repo}" == "1" && -d "${chromium_dir}/.git" ]] && . "${BUILD_HOME}"/git_deep_clean.sh -cg -d "${chromium_dir}"
[[ "${clean_repo}" == "1" && -d "${chromium_dir}/src/.git" ]] && . "${BUILD_HOME}"/git_deep_clean.sh -cgx -d "${chromium_dir}/src"

exit 0

