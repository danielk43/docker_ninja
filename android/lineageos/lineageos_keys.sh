#!/usr/bin/env bash

# shellcheck disable=SC2154

export LINEAGEOS_SIGNING_KEYS=(bluetooth cyngn-app media networkstack nfc platform \
                             releasekey sdk_sandbox shared testcert testkey verity)
export LINEAGEOS_APEX_KEYS=(com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch \
                          com.android.appsearch.apk com.android.art com.android.bluetooth com.android.bt \
                          com.android.btservices com.android.cellbroadcast com.android.compos com.android.configinfrastructure \
                          com.android.connectivity.resources com.android.conscrypt com.android.crashrecovery \
                          com.android.devicelock com.android.extservices com.android.graphics.pdf com.android.hardware.authsecret \
                          com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual \
                          com.android.hardware.boot com.android.hardware.cas com.android.hardware.contexthub \
                          com.android.hardware.dumpstate com.android.hardware.gatekeeper.nonsecure \
                          com.android.hardware.neuralnetworks com.android.hardware.power com.android.hardware.rebootescrow \
                          com.android.hardware.thermal com.android.hardware.threadnetwork com.android.hardware.uwb \
                          com.android.hardware.vibrator com.android.hardware.wifi com.android.healthfitness \
                          com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media \
                          com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet \
                          com.android.networkstack.tethering com.android.neuralnetworks com.android.nfcservices \
                          com.android.ondevicepersonalization com.android.os.statsd com.android.permission \
                          com.android.profiling com.android.resolv com.android.rkpd com.android.runtime \
                          com.android.safetycenter.resources com.android.scheduling com.android.sdkext \
                          com.android.support.apexer com.android.telephony com.android.telephonymodules \
                          com.android.tethering com.android.tzdata com.android.uprobestats com.android.uwb \
                          com.android.uwb.resources com.android.virt com.android.vndk.current \
                          com.android.vndk.current.on_vendor com.android.wifi com.android.wifi.dialog \
                          com.android.wifi.resources com.google.pixel.camera.hal com.google.pixel.vibrator.hal \
                          com.qorvo.uwb)

make_lineageos_keys() {
  mkdir "${device_keys}" 2>/dev/null || true
  pushd "${device_keys}" >/dev/null || exit
  sed -i "s/2048/4096/g" "${MAKE_KEY}" # use SHA256_RSA4096

  for key in "${LINEAGEOS_SIGNING_KEYS[@]}"
  do
    if [[ ! -f "${key}.pk8" ]]
    then
      echo "${!keys_password}" | "${MAKE_KEY}" "${key}" "${android_dname}" &>/dev/null || echo -e "creating ${key}.pk8"
    fi
    if [[ -n "${!keys_password}" ]] && ! grep -q "${device_keys}/${key}$" pw_file 2>/dev/null
    then
      echo "[[[ ${!keys_password} ]]] ${device_keys}/${key}" >> pw_file
    fi
  done

  for apex in "${LINEAGEOS_APEX_KEYS[@]}"
  do
    if [[ ! -f "${apex}.pk8" ]]
    then
      echo "${!keys_password}" | "${MAKE_KEY}" "${apex}" "${android_dname}" &>/dev/null || echo -e "creating ${apex}.pk8"
      if [[ -n "${!keys_password}" ]]
      then
        openssl pkcs8 -in "${apex}".pk8 -inform DER -passin pass:"${!keys_password}" -out "${apex}".pem >/dev/null
      fi
    fi
    if [[ -n "${!keys_password}" ]] && ! grep -q "${device_keys}/${apex}$" pw_file 2>/dev/null
    then
      echo "[[[ ${!keys_password} ]]] ${device_keys}/${apex}" >> pw_file
    fi
  done

  if [[ ! -f avb.pem ]]
  then
    openssl genrsa 4096 | openssl pkcs8 -topk8 -nocrypt -out avb.pem && echo "creating avb.pem"
    ${AVB_TOOL} extract_public_key --key avb.pem --output avb_pkmd.bin >/dev/null && echo "creating avb_pkmd.bin"
  fi

  [[ -f "${device_keys}/pw_file" ]] && export ANDROID_PW_FILE="${device_keys}/pw_file"
  popd >/dev/null || exit
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

