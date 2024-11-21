# docker_ninja
## build
Build LineageOS or GrapheneOS noninteractively  

### Docker
(Recommended)

GrapheneOS example
```
docker run --rm \
-e "ANDROID_VERSION=grapheneos-14" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "DEVICES=lynx raven" \
-e "GRAPHENEOS_TAG=latest" \
-e "KEYS_PASSWORD_LYNX=${KEYS_PASSWORD_LYNX}" \
-e "KEYS_PASSWORD_RAVEN=${KEYS_PASSWORD_RAVEN}" \
-e "USER_SCRIPTS=/android_build/scripts/apply_patches1.sh" \
-e "VANADIUM_PASSWORD=${VANADIUM_PASSWORD}" \
-e "YARN=true" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/grapheneos-kernel:/android_build/kernel" \
-v "/path/to/android/grapheneos/keys:/android_build/keys" \
-v "/path/to/android/grapheneos/ROMs:/android_build/out" \
-v "/path/to/scripts:/android_build/scripts" \
-v "/path/to/src:/android_build/src" \
-v "/path/to/vanadium:/android_build/vanadium" \
danielk43/docker_ninja:latest
```

LineageOS example
```
docker run --rm \
-e "ANDROID_VERSION=lineageos-20.0" \
-e "BUILD_TYPE=mdklabs" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "DELETE_ROOMSERVICE=true" \
-e "DEVICES=barbet" \
-e "SCRIPTS_DIR=/android_build/scripts" \
-e "GMS_MAKEFILE=gms_extras.mk" \
-e "SIGN_LINEAGEOS=true" \
-e "USER_SCRIPTS=/android_build/scripts/apply_patches1.sh \
                 /android_build/scripts/apply_patches2.sh" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/android/lineageos/keys:/android_build/keys" \
-v "/path/to/android/lineageos/ROMs:/android_build/out" \
-v "/path/to/scripts:/android_build/scripts" \
-v "/path/to/src:/android_build/src" \
danielk43/docker_ninja:latest
```

### Standalone / Host
(not recommended)

Required Debian or Ubuntu 22+
See `./build_android.sh -h` for usage

### Notes
WIP
