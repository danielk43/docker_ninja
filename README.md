# docker_ninja
## build
Build Android OS images noninteractively  

### Docker
```
docker pull danielk43/docker_ninja:latest
```

GrapheneOS supported options
```
docker run --rm \
-e "ANDROID_VERSION=grapheneos-15" \ # Will look in src/.repo (Optional)
-e "BUILD_TYPE=custom" \ # Android build type (Optional)
-e "BUILD_VARIANT=user" \ # Or eng, default is userdebug (Optional)
-e "CCACHE_SIZE=100G" \ # Default is 50G (Optional)
-e "CLEAN_REPO=true" \ # Default is false (Optional)
-e "DEVICES=lynx akita" \ # Device codenames
-e "DNAME_ANDROID=/CN=GrapheneOS/" \ # Default /CN=Android/ (Optional)
-e "DNAME_ANDROID=/CN=Chrome/" \ # Default CN=Chromium (Optional)
-e "KEYS_PASSWORD_LYNX=${KEYS_PASSWORD_LYNX}" \ # Device signing key password
-e "KEYS_PASSWORD_AKITA=${KEYS_PASSWORD_AKITA}" \
-e "KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}" \ # Chromium keystore password
-e "OFFICIAL_BUILD=true" \ # Official build, must also patch update server, default flase (Optional)
-e "PERSIST_VENDOR=true" \ # Don't reset vendor, default false (Optional)
-e "PRINT_ENV=true" \ # Print env vars, default is false (Optional)
-e "RELEASE_TAG=dev" \ # Or latest, or explicit tag (Optional)
-e "SYNC_JOBS=8" \ # Number of parallel jobs during repo sync, default is nproc (Optional)
-e "SYNC_RETRIES=10" \ # Number of retries if repo sync fails, default is 5 (Optional)
-e "USER_SCRIPTS=/android_build/scripts/apply_patches.sh \ # User scripts to run before build (Optional)
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/grapheneos-kernel:/android_build/kernel" \
-v "/path/to/android/grapheneos/keys:/android_build/keys" \
-v "/path/to/android/grapheneos/ROMs:/android_build/out" \
-v "/path/to/userscripts:/android_build/scripts" \ # Optional
-v "/path/to/src:/android_build/src" \
-v "/path/to/vanadium:/android_build/chromium" \ # Optional
danielk43/ninja_android:latest
```

CalyxOS supported options
```
docker run --rm \
-e "ANDROID_VERSION=calyxos-15" \
-e "BUILD_TYPE=custom" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "CLEAN_REPO=false" \
-e "DEVICES=shiba" \
-e "DNAME_ANDROID=/CN=LineageOS/" \
-e "DNAME_ANDROID=/CN=Chrome/" \
-e "PERSIST_VENDOR=true" \
-e "PRINT_ENV=true" \
-e "RELEASE_TAG=latest" \
-e "SIGN_BUILD=true" \ # Generate keys and sign build, default false (Optional)
-e "SYNC_JOBS=8" \
-e "SYNC_RETRIES=10" \
-e "USER_SCRIPTS=/android_build/scripts/apply_patches.sh \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/calyxos/keys:/android_build/keys" \
-v "/path/to/calyxos/ROMs:/android_build/out" \
-v "/path/to/userscripts:/android_build/scripts" \
-v "/path/to/src/vendor/factory_images:/tmp/pixel" \ # Cache vendor images (Optional)
-v "/path/to/src:/android_build/src" \
danielk43/ninja_android:latest
```

LineageOS supported options
```
docker run --rm \
-e "ANDROID_VERSION=lineageos-22.1" \
-e "BUILD_TYPE=custom" \
-e "BUILD_VARIANT=user" \
-e "CCACHE_SIZE=100G" \
-e "CLEAN_REPO=true" \
-e "DELETE_ROOMSERVICE=true" \ # Remove previous dependencies, default false (Optional)
-e "DEVICES=barbet" \
-e "GMS_MAKEFILE=gms_extras.mk" \ # Also sets WITH_GMS=true (Optional)
-e "PRINT_ENV=true" \
-e "SIGN_BUILD=true" \
-e "SYNC_JOBS=8" \
-e "SYNC_RETRIES=10" \
-e "USER_SCRIPTS=/android_build/scripts/apply_patches1.sh \
                 /android_build/scripts/apply_patches2.sh" \
-v "/path/to/.ccache:/android_build/ccache" \
-v "/path/to/android/lineageos/keys:/android_build/keys" \
-v "/path/to/android/lineageos/ROMs:/android_build/out" \
-v "/path/to/userscripts:/android_build/scripts" \
-v "/path/to/src:/android_build/src" \
danielk43/ninja_android:latest
```

### Notes
WIP
