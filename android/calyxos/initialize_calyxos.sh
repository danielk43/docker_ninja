#!/usr/bin/env bash

usage() {
  echo "Usage:"
  echo "  ./build_calyxos.sh [ options ]"
  echo
  echo "  Options:"
  echo "    -a Android repo top (user-provided croot dir; same as \$ANDROID_BUILD_TOP)"
  echo "    -b calyxos Build type (PRODUCT_VERSION_EXTRA: defaults to UNOFFICIAL)"
  echo "    -c Ccache size (defaults to 50G)"
  echo "    -d space-separated Device codenames to build (\"device1 device2 ...\")"
  echo "    -e space-separated extra Env vars to be exported (\"k1=v1 k2=v2 ...\")"
  echo "    -f target build Flavor / variant (defaults to userdebug. also accepts user, eng)"
  echo "    -g Android keys distinGuished name (defaults to \"/CN=Android/\")"
  echo "    -h print this Help menu and exit"
  echo "    -i offIcial calyxos build (must configure update server url)"
  echo "    -j number of Jobs during repo sync (defaults to nproc)"
  echo "    -k calyxos Keys dir (enforced if -s is set, requires each device dir with keyfiles inside)"
  echo "    -l deep cLean android src (git expire reflog, prune now)"
  echo "    -m gms Makefle (set filename if vendor/partner_gms exists, also sets WITH_GMS=true)"
  echo "    -n kerNel root directory (unsupported/wip currently)"
  echo "    -o Out dir for completed build images (defaults to \$ANDROID_BUILD_TOP/releases)"
  echo "    -p number of retries for rePo sync if errors encountered (defaults to 7)"
  echo "    -q Chromium keys distinguished name (defaults to \"/CN=Chromium/\")"
  echo "    -s Sign build (keys will be auto-generated, see https://calyxos.org/docs/development/build/sign)"
  echo "    -u space-separated paths to User scripts (\"/path/to/user.sh /path/to/patch.sh ...\")"
  echo "    -v android Version (in format \"calyxos-xx\")"
  echo "    -w Write environment to stdout"
  echo "    -z mapbox api key"
  echo
  echo "  Example:"
  echo "    ./build_android.sh -a \$CALYXOS_TOP -d \"barbet lynx\" -f user \\"
  echo "    -k \"\$HOME/.android-certs/calyxos\" -j$(nproc) -ls -u \"\$HOME/patch.sh\" -v calyxos-14"
  echo
  exit 1
}

