#!/usr/bin/env bash

# shellcheck disable=SC2154

export GRAPHENEOS_SIGNING_KEYS=(bluetooth gmscompat_lib media networkstack platform releasekey sdk_sandbox shared)

make_grapheneos_keys() {
  mkdir "${device_keys}" 2>/dev/null || true
  pushd "${device_keys}" >/dev/null || exit

  for key in "${GRAPHENEOS_SIGNING_KEYS[@]}"
  do
    if [[ ! -f "${key}.pk8" ]]
    then
      echo "${!keys_password}" | "${MAKE_KEY}" "${key}" "${android_dname}" &>/dev/null || echo "creating ${key}.pk8"
    fi
  done

  if [[ ! -f avb.pem ]]
  then
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -passout pass:"${!keys_password}" -out avb.pem >/dev/null
    expect << EOF
      set timeout -1
      spawn ${AVB_TOOL} extract_public_key --key avb.pem --output avb_pkmd.bin
      expect "Enter pass phrase"
      send -- "${!keys_password}\r"
      expect eof
EOF
  fi

  if [[ ! -f id_ed25519 ]]
  then
    expect << EOF
      set timeout -1
      spawn ssh-keygen -t ed25519 -f id_ed25519
      expect "Enter passphrase"
      send -- "${!keys_password}\r"
      expect "Enter same passphrase"
      send -- "${!keys_password}\r"
      expect eof
EOF
  fi

  popd >/dev/null || exit
}

