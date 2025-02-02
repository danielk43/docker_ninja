# docker_ninja
## build
Build Android OS images noninteractively  

### Docker
(Recommended)

GrapheneOS example
```
docker run --rm \
-e "ANDROID_VERSION=grapheneos-14" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "CLEAN_REPO=false" \
-e "DEVICES=lynx akita" \
-e "RELEASE_TAG=dev" \
-e "KEYS_PASSWORD_LYNX=${KEYS_PASSWORD_LYNX}" \
-e "KEYS_PASSWORD_AKITA=${KEYS_PASSWORD_AKITA}" \
-e "VANADIUM_PASSWORD=${VANADIUM_PASSWORD}" \
-e "YARN=true" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/grapheneos-kernel:/android_build/kernel" \
-v "/path/to/android/grapheneos/keys:/android_build/keys" \
-v "/path/to/android/grapheneos/ROMs:/android_build/out" \
-v "/path/to/src:/android_build/src" \
-v "/path/to/vanadium:/android_build/chromium" \
danielk43/ninja_android:latest
```

CalyxOS example
```
docker run --rm \
-e "BUILD_TYPE=custom" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "CLEAN_REPO=false" \
-e "DEVICES=shiba" \
-e "RELEASE_TAG=latest" \
-e "SIGN_BUILD=true" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/calyxos/keys:/android_build/keys" \
-v "/path/to/calyxos/ROMs:/android_build/out" \
-v "/path/to/userscripts:/android_build/scripts" \
-v "/path/to/src/vendor/factory_images:/tmp/pixel" \
-v "/path/to/src:/android_build/src" \
danielk43/ninja_android:latest
```

LineageOS example
```
docker run --rm \
-e "ANDROID_VERSION=lineageos-22.1" \
-e "BUILD_TYPE=custom" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "CLEAN_REPO=true" \
-e "DELETE_ROOMSERVICE=true" \
-e "DEVICES=barbet" \
-e "GMS_MAKEFILE=gms_extras.mk" \
-e "SIGN_LINEAGEOS=true" \
-e "USER_SCRIPTS=/android_build/scripts/apply_patches1.sh \
                 /android_build/scripts/apply_patches2.sh" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/android/lineageos/keys:/android_build/keys" \
-v "/path/to/android/lineageos/ROMs:/android_build/out" \
-v "/path/to/userscripts:/android_build/scripts" \
-v "/path/to/src:/android_build/src" \
danielk43/ninja_android:latest
```

### Standalone / Host
(not recommended)

Required Debian or Ubuntu 22+
See `./build_android.sh -h` for usage

### Notes
WIP
