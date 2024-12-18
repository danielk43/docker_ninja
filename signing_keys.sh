#!/usr/bin/env bash

# shellcheck disable=SC2154

export AVB_TOOL="${android_top}/external/avb/avbtool.py"
export MAKE_KEY="${android_top}/development/tools/make_key"
export GRAPHENEOS_SIGNING_KEYS=(bluetooth media networkstack platform releasekey sdk_sandbox shared)
export LINEAGEOS_SIGNING_KEYS=(bluetooth cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared testcert testkey verity)
export LINEAGEOS_APEX_KEYS=(com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch \
                          com.android.appsearch.apk com.android.art com.android.bluetooth com.android.btservices \
                          com.android.cellbroadcast com.android.compos com.android.configinfrastructure \
                          com.android.connectivity.resources com.android.conscrypt com.android.devicelock \
                          com.android.extservices com.android.graphics.pdf com.android.hardware.authsecret \
                          com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual \
                          com.android.hardware.boot com.android.hardware.cas com.android.hardware.neuralnetworks \
                          com.android.hardware.rebootescrow com.android.hardware.wifi com.android.healthfitness \
                          com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media \
                          com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet \
                          com.android.networkstack.tethering com.android.neuralnetworks com.android.nfcservices \
                          com.android.ondevicepersonalization com.android.os.statsd com.android.permission \
                          com.android.profiling com.android.resolv com.android.rkpd com.android.runtime \
                          com.android.safetycenter.resources com.android.scheduling com.android.sdkext \
                          com.android.support.apexer com.android.telephony com.android.telephonymodules \
                          com.android.tethering com.android.tzdata com.android.uwb com.android.uwb.resources \
                          com.android.virt com.android.vndk.current com.android.vndk.current.on_vendor com.android.wifi \
                          com.android.wifi.dialog com.android.wifi.resources com.google.pixel.camera.hal \
                          com.google.pixel.vibrator.hal com.qorvo.uwb)

make_grapheneos_keys() {
  cd "${device_keys}" || exit
  if test -n "$(find . -maxdepth 0 -empty)"
  then
    [[ -z "${dname}" ]] && dname="/CN=GrapheneOS/"
    for key in "${GRAPHENEOS_SIGNING_KEYS[@]}"
    do
      echo "${!keys_password}" | "${MAKE_KEY}" "${key}" "${dname}" > /dev/null 2>&1 || echo "creating ${key}.pk8"
    done
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -passout pass:"${!keys_password}" -out avb.pem && echo "creating avb.pem"
    expect << END
      set timeout -1
      spawn ${AVB_TOOL} extract_public_key --key avb.pem --output avb_pkmd.bin
      expect "Enter pass phrase"
      send -- "${!keys_password}\r"
      spawn ssh-keygen -t ed25519 -f id_ed25519
      expect "Enter passphrase"
      send -- "${!keys_password}\r"
      expect "Enter same passphrase"
      send -- "${!keys_password}\r"
      expect eof
END
  else
    echo "INFO: ${device_keys} not empty, skipping keygen"
  fi
  cd "${android_top}" || exit
}

make_lineageos_keys() {
  cd "${device_keys}" || exit
  sed -i "s/2048/4096/g" "${MAKE_KEY}" # use SHA256_RSA4096
  if test -n "$(find . -maxdepth 0 -empty)"
  then
    [[ -z "${dname}" ]] && dname="/CN=Android/"
    for key in "${LINEAGEOS_SIGNING_KEYS[@]}"
    do
      echo "${!keys_password}" | "${MAKE_KEY}" "${key}" "${dname}" > /dev/null 2>&1 || echo -e "creating ${key}.pk8\ncreating ${key}.pem"
      if [[ -n "${!keys_password}" ]]
      then
        echo "[[[ ${!keys_password} ]]] ${device_keys}/${key}" >> pw_file
      fi
    done
    for apex in "${LINEAGEOS_APEX_KEYS[@]}"
    do
      echo "${!keys_password}" | "${MAKE_KEY}" "${apex}" "${dname}" > /dev/null 2>&1 || echo -e "creating ${apex}.pk8\ncreating ${apex}.pem"
      if [[ -n "${!keys_password}" ]]
      then
        openssl pkcs8 -in "${apex}".pk8 -inform DER -passin pass:"${!keys_password}" -out "${apex}".pem
        echo "[[[ ${!keys_password} ]]] ${device_keys}/${apex}" >> pw_file
      fi
    done
    openssl genrsa 4096 | openssl pkcs8 -topk8 -nocrypt -out avb.pem && echo "creating avb.pem"
    ${AVB_TOOL} extract_public_key --key avb.pem --output avb_pkmd.bin > /dev/null && echo "creating avb_pkmd.bin"
  else
    echo "INFO: ${device_keys} not empty, skipping keygen"
  fi
  [[ -f "${device_keys}/pw_file" ]] && export ANDROID_PW_FILE="${device_keys}/pw_file"
  cd "${android_top}" || exit
}

extra_apks_args() {
  for apex in "${LINEAGEOS_APEX_KEYS[@]}"
  do
    printf "%s" "--extra_apks ${apex}.apex=${device_keys}/${apex} --extra_apex_payload_key ${apex}.apex=${device_keys}/${apex}.pem "
  done
  cat << EOF
    --extra_apks AdServicesApk.apk=${device_keys}/releasekey \
    --extra_apks FederatedCompute.apk=${device_keys}/releasekey \
    --extra_apks HalfSheetUX.apk=${device_keys}/releasekey \
    --extra_apks HealthConnectBackupRestore.apk=${device_keys}/releasekey \
    --extra_apks HealthConnectController.apk=${device_keys}/releasekey \
    --extra_apks OsuLogin.apk=${device_keys}/releasekey \
    --extra_apks SafetyCenterResources.apk=${device_keys}/releasekey \
    --extra_apks ServiceConnectivityResources.apk=${device_keys}/releasekey \
    --extra_apks ServiceUwbResources.apk=${device_keys}/releasekey \
    --extra_apks ServiceWifiResources.apk=${device_keys}/releasekey \
    --extra_apks WifiDialog.apk=${device_keys}/releasekey
EOF
}

