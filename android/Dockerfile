FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG HOME=/android_build

WORKDIR $HOME

ENV ANDROID_HOME=$HOME/cmdline-tools
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
ENV GMS_MAKEFILE=""
ENV OFFICIAL_BUILD=""
ENV PERSIST_VENDOR=""
ENV PRINT_ENV=""
ENV RELEASE_TAG=""
ENV SIGN_BUILD=""
ENV SYNC_JOBS=""
ENV SYNC_RETRIES=""
ENV USER_SCRIPTS=""

RUN apt update \
 && apt -y upgrade \
 && apt -y install curl git-core \
 && curl -L https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
 && curl -L https://deb.nodesource.com/setup_20.x | bash \
 && apt install -y bc binutils bison build-essential ccache cgpt expect file flex g++-multilib \
    gcc-multilib git-lfs gperf imagemagick jq lib32readline-dev lib32z1-dev libdbus-1-dev libdrm-dev \
    libelf-dev libgcc-s1 libkrb5-dev liblz4-tool libncurses5 libncurses5-dev libnss3-dev libsdl1.2-dev \
    libssl-dev libxml2 libxml2-utils lz4 lzop m4 nodejs openjdk-17-jdk openssh-server pngcrush \
    python-is-python3 python3-pip rsync schedtool squashfs-tools wget xsltproc xxd zip zlib1g-dev \
 && curl -LO https://dl.google.com/android/repository/platform-tools-latest-linux.zip \
 && unzip platform-tools-latest-linux.zip \
 && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
 && curl -L https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo \
 && chmod a+x /usr/local/bin/repo \
 && curl -LO $(curl -s https://api.github.com/repos/protocolbuffers/protobuf/releases/latest \
  | grep "browser_download_url.*linux-x86_64.zip" | cut -d\" -f4) \
 && unzip -o protoc-*-linux-x86_64.zip -d /usr/local bin/protoc \
 && unzip -o protoc-*-linux-x86_64.zip -d /usr/local include/* \
 && pip3 install --break-system-packages --no-cache-dir lxml protobuf pyyaml \
 && apt -y autoremove \
 && apt autoclean \
 && rm -rf /var/cache/apt/* *.zip \
 && npm install --global --upgrade yarn \
 && npm cache clean --force \
 && HOME=/root git config --global user.name "Ninja CI bot" \
 && HOME=/root git config --global user.email "ninja@docker.local" \
 && HOME=/root git config --global color.ui false \
 && HOME=/root git config --global advice.detachedHead false \
 && HOME=/root git config --global http.postBuffer 524288000 \
 && HOME=/root git config --global pack.windowMemory "4096m" \
 && echo 'alias ll="ls -alF"' >> /root/.bashrc \
 && ln -sf /proc/1/fd/1 /var/log/docker.log

COPY --chmod=0755 make_common.sh android/make_common.sh
COPY --chmod=0755 git_deep_clean.sh android/git_deep_clean.sh
COPY --chmod=0755 calyxos android/calyxos
COPY --chmod=0755 grapheneos android/grapheneos
COPY --chmod=0755 lineageos android/lineageos

CMD ["/bin/bash", "android/make_common.sh"]
