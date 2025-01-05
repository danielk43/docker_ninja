#!/usr/bin/env bash

# Build Vanadium once, outside of devices loop
if [[ -n "${VANADIUM_PASSWORD}" && -d ${chromium_dir} ]]
then
  cd "${chromium_dir}"
  [[ -f "args.gn" ]] || git clone https://github.com/GrapheneOS/Vanadium.git .
  clean_repo
  [[ -f /.dockerenv ]] && git config --global --add safe.directory "${chromium_dir}"
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
  [[ -f /.dockerenv ]] && git config --global --add safe.directory "${PWD}" \
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

