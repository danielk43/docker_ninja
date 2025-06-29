#!/usr/bin/env bash

# shellcheck disable=SC2154

export GRAPHENEOS_SIGNING_KEYS=(bluetooth media networkstack platform releasekey sdk_sandbox shared)

make_grapheneos_keys() {
  pushd "${device_keys}" >/dev/null || exit
  if test -n "$(find . -maxdepth 0 -empty)"
  then
    for key in "${GRAPHENEOS_SIGNING_KEYS[@]}"
    do
      echo "${!keys_password}" | "${MAKE_KEY}" "${key}" "${android_dname}" >/dev/null 2>&1 || echo "creating ${key}.pk8"
    done
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -passout pass:"${!keys_password}" -out avb.pem >/dev/null
    expect << EOF
      set timeout -1
      spawn ${AVB_TOOL} extract_public_key --key avb.pem --output avb_pkmd.bin
      expect "Enter pass phrase"
      send -- "${!keys_password}\r"
      expect eof
EOF
    expect << EOF
      set timeout -1
      spawn ssh-keygen -t ed25519 -f id_ed25519
      expect "Enter passphrase"
      send -- "${!keys_password}\r"
      expect "Enter same passphrase"
      send -- "${!keys_password}\r"
      expect eof
EOF
  else
    echo "INFO: ${device_keys} not empty, skipping keygen"
  fi
  popd >/dev/null || exit
}

