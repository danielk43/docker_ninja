FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG HOME=/android_build
ARG JDK_VERSION=21
ARG NODEJS_VERSION=22

WORKDIR $HOME

ENV USE_CCACHE=1
ENV CCACHE_COMPRESSLEVEL=1
ENV CCACHE_DIR=$HOME/ccache
ENV CCACHE_EXEC=/usr/bin/ccache
ENV CCACHE_SIZE=50G
ENV PATH="$HOME/depot_tools:$HOME/platform-tools:$PATH"
ENV REBASELINE_PROGUARD=1

ENV ANDROID_VERSION=""
ENV BUILD_TYPE=""
ENV BUILD_VARIANT=userdebug
ENV CLEAN_REPO=""
ENV DELETE_ROOMSERVICE=""
ENV DEVICES=""
ENV DNAME_ANDROID=""
ENV DNAME_CHROMIUM=""
ENV EXPIRE_SINCE=""
ENV GMS_MAKEFILE=""
ENV OFFICIAL_BUILD=""
ENV PERSIST_VENDOR=""
ENV PRINT_ENV=""
ENV PRUNE_SINCE=""
ENV RELEASE_TAG=""
ENV SIGN_BUILD=""
ENV SYNC_JOBS=""
ENV SYNC_RETRIES=""
ENV USER_SCRIPTS=""

RUN apt update \
 && apt -y upgrade \
 && apt -y install curl git-core zip \
 && curl -L https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
 && curl -L https://deb.nodesource.com/setup_"$NODEJS_VERSION".x | bash \
 && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | \
    gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg \
 && echo "deb https://packages.adoptium.net/artifactory/deb trixie main" | \
    tee /etc/apt/sources.list.d/adoptium.list \
 && curl -LO https://dl.google.com/android/repository/platform-tools-latest-linux.zip \
 && unzip platform-tools-latest-linux.zip \
 && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
 && cd $HOME/depot_tools \
 && ./update_depot_tools \
 && cd $HOME \
 && curl -LO $(curl -s https://api.github.com/repos/protocolbuffers/protobuf/releases/latest \
  | grep "browser_download_url.*linux-x86_64.zip" | cut -d\" -f4) \
 && unzip -o protoc-*-linux-x86_64.zip -d /usr/local bin/protoc \
 && unzip -o protoc-*-linux-x86_64.zip -d /usr/local include/* \
 && apt update \
 && apt install -y bc binutils bison build-essential ccache cgpt e2fsprogs expect file flex git-lfs \
    gperf imagemagick jq lib32readline-dev lib32z1-dev libdbus-1-dev libdrm-dev libelf-dev libgcc-s1 \
    libkrb5-dev liblz4-dev libnss3-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lz4 lzop m4 \
    nodejs temurin-"$JDK_VERSION"-jdk openssh-server pngcrush python-is-python3 python3-pip rsync \
    schedtool squashfs-tools wget xsltproc xxd zlib1g-dev \
 && pip3 install --break-system-packages --no-cache-dir lxml protobuf pyyaml \
 && apt -y autoremove \
 && apt -y clean \
 && rm -rf *.zip \
 && npm install --global --upgrade yarn \
 && npm cache clean --force \
 && HOME=/root git config --global user.name "Ninja CI bot" \
 && HOME=/root git config --global user.email "ninja@docker.local" \
 && HOME=/root git config --global color.ui false \
 && HOME=/root git config --global advice.detachedHead false \
 && HOME=/root git config --global http.postBuffer 524288000 \
 && HOME=/root git config --global pack.windowMemory "4096m" \
 && HOME=/root git config --global trailer.changeid.key "Change-Id" \
 && echo 'alias ll="ls -alF"' >> /root/.bashrc

COPY --chmod=0755 make_common.sh android/make_common.sh
COPY --chmod=0755 git_deep_clean.sh android/git_deep_clean.sh
COPY --chmod=0755 calyxos android/calyxos
COPY --chmod=0755 grapheneos android/grapheneos
COPY --chmod=0755 lineageos android/lineageos

CMD ["/bin/bash", "android/make_common.sh"]
