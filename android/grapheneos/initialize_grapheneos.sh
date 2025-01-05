#!/usr/bin/env bash

usage() {
  echo "Usage:"
  echo "  ./build_grapheneos.sh [ options ]"
  echo
  echo "Each device's GrapheneOS signing key password must be set in the environment as"
  echo "KEYS_PASSWORD_<DEVICE>: e.g., \$KEYS_PASSWORD_RAVEN"
  echo
  echo "VANADIUM_PASSWORD for vanadium.keystore must be over six characters"
  echo "VANADIUM_PASSWORD and -v option together trigger browser build"
  echo
  echo "  Options:"
  echo "    -a Android repo top (user-provided croot dir; same as \$ANDROID_BUILD_TOP)"
  echo "    -c Ccache size (defaults to 50G)"
  echo "    -d space-separated Device codenames to build (\"device1 device2 ...\")"
  echo "    -e space-separated extra Env vars to be exported (\"k1=v1 k2=v2 ...\")"
  echo "    -f target build Flavor / variant (defaults to userdebug. also accepts user, eng)"
  echo "    -g Android keys distinGuished name (defaults to \"/CN=Android/\")"
  echo "    -h print this Help menu and exit"
  echo "    -i offIcial grapheneos build (must configure update server url)"
  echo "    -j number of Jobs during repo sync (defaults to nproc)"
  echo "    -k grapheneos Keys dir (enforced if -s is set, requires each device dir with keyfiles inside)"
  echo "    -l deep cLean android src (git expire reflog, prune now)"
  echo "    -m gms Makefle (set filename if vendor/partner_gms exists, also sets WITH_GMS=true)"
  echo "    -n grapheneos kerNel root directory (above each device family repo)"
  echo "    -o Out dir for completed build images (defaults to \$ANDROID_BUILD_TOP/releases)"
  echo "    -p number of retries for rePo sync if errors encountered (defaults to 7)"
  echo "    -q Chromium keys distinguished name (defaults to \"/CN=Chromium/\")"
  echo "    -t grapheneos release Tag (or \"latest\" for latest stable, omit or \"dev\" for development)"
  echo "    -u space-separated paths to User scripts (\"/path/to/user.sh /path/to/patch.sh ...\")"
  echo "    -v android Version (in format \"grapheneos-xx\" for grapheneos and \"lineageos-xx.x\" for lineageos)"
  echo "    -w Write environment to stdout"
  echo "    -x vanadium dir (build browser for grapheneos. remote name must contain \"vanadium\")"
  echo "    -y Yarn install adevtool and extract grapheneos vendor files"
  echo
  echo "  Example:"
  echo "    ./build_grapheneos.sh -a \$GRAPHENEOS_TOP -d \"shiba\" -f user \\"
  echo "    -k \"\$HOME/.android-certs/grapheneos\" -m gms_custom.mk -t latest -u \"\$HOME/patch.sh\" -v grapheneos-15"
  echo
  exit 1
}

# Initialize signing keys
. "${build_path}"/"${android_platform}"_keys.sh

