#!/usr/bin/env bash

usage() {
  echo "Usage:"
  echo "  ./build_lineageos.sh [ options ]"
  echo
  echo "  Options:"
  echo "    -a Android repo top (user-provided croot dir; same as \$ANDROID_BUILD_TOP)"
  echo "    -b Build type (LINEAGE_BUILDTYPE: defaults to UNOFFICIAL)"
  echo "    -c Ccache size (defaults to 50G)"
  echo "    -d space-separated Device codenames to build (\"device1 device2 ...\")"
  echo "    -e space-separated extra Env vars to be exported (\"k1=v1 k2=v2 ...\")"
  echo "    -f target build Flavor / variant (defaults to userdebug. also accepts user, eng)"
  echo "    -g Android keys distinGuished name (defaults to \"/CN=Android/\")"
  echo "    -h print this Help menu and exit"
  echo "    -i offIcial lineageos build (must configure update server url)"
  echo "    -j number of Jobs during repo sync (defaults to nproc)"
  echo "    -k lineageos Keys dir (enforced if -s is set, requires each device dir with keyfiles inside)"
  echo "    -l deep cLean android src (git expire reflog, prune now)"
  echo "    -m gms Makefle (set filename if vendor/partner_gms exists, also sets WITH_GMS=true)"
  echo "    -o Out dir for completed build images (defaults to \$ANDROID_BUILD_TOP/releases)"
  echo "    -p number of retries for rePo sync if errors encountered (defaults to 7)"
  echo "    -r delete Roomservice.xml (if local_manifests are user-defined)"
  echo "    -s Sign lineageos build (requires keys, see https://wiki.lineageos.org/signing_builds)"
  echo "    -u space-separated paths to User scripts (\"/path/to/user.sh /path/to/patch.sh ...\")"
  echo "    -v android Version (in format \"lineageos-xx.x\")"
  echo "    -w Write environment to stdout"
  echo
  echo "  Example:"
  echo "    ./build_lineageos.sh -a \$LINEAGEOS_TOP -d \"barbet lynx\" -f user \\"
  echo "    -k \"\$HOME/.android-certs/lineageos\" -m gms_custom.mk -rs -u \"\$HOME/patch.sh\" -v lineageos-21.0"
  echo
  exit 1
}

# Initialize signing keys
. "${build_path}"/"${android_platform}"_keys.sh

