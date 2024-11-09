FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG HOME=/android_build

WORKDIR $HOME

ENV PATH="$HOME/depot_tools:$HOME/platform-tools:$PATH"
ENV USE_CCACHE=1
ENV CCACHE_COMPRESSLEVEL=1
ENV CCACHE_DIR=$HOME/ccache
ENV CCACHE_EXEC=/usr/bin/ccache
ENV CCACHE_SIZE=50G
ENV REBASELINE_PROGUARD=1

ENV ANDROID_VERSION=""
ENV BUILD_VARIANT=userdebug
ENV DELETE_ROOMSERVICE=""
ENV DEVICES=""
ENV GMS_MAKEFILE=""
ENV GRAPHENEOS_TAG=""
ENV LINEAGE_BUILDTYPE=""
ENV OFFICIAL_BUILD=""
ENV SIGN_LINEAGEOS=""
ENV SYNC_JOBS=""
ENV SYNC_RETRIES=""
ENV USER_SCRIPTS=""
ENV YARN=""

RUN mkdir bin \
 && apt update \
 && apt -y upgrade \
 && apt -y install curl \
                   git-core \
                   zip \
 && curl -LO https://dl.google.com/android/repository/platform-tools-latest-linux.zip \
 && unzip platform-tools-latest-linux.zip \
 && rm -f platform-tools-latest-linux.zip \
 && curl -L https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo \
 && chmod a+x /usr/local/bin/repo \
 && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
 && curl -L https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
 && curl -L https://deb.nodesource.com/setup_20.x | bash \
 && apt install -y bc \
                   binutils \
                   bison \
                   build-essential \
                   ccache \
                   cgpt \
                   flex \
                   g++-multilib \
                   gcc-multilib \
                   git-lfs \
                   gperf \
                   imagemagick \
                   jq \
                   lib32readline-dev \
                   lib32z1-dev \
                   libdbus-1-dev \
                   libdrm-dev \
                   libelf-dev \
                   libgcc-s1 \
                   libkrb5-dev \
                   liblz4-tool \
                   libncurses5 \
                   libnss3-dev \
                   libsdl1.2-dev \
                   libssl-dev \
                   libxml2 \
                   libxml2-utils \
                   lzop \
                   nodejs \
                   openjdk-17-jdk \
                   openssh-server \
                   pngcrush \
                   python-is-python3 \
                   python3 \
                   rsync \
                   schedtool \
                   squashfs-tools \
                   wget \
                   xsltproc \
                   xxd \
                   zip \
                   zlib1g-dev \
 && HOME=/root git config --global user.name "Docker CI Bot" \
 && HOME=/root git config --global user.email "ci-bot@docker.local" \
 && HOME=/root git config --global advice.detachedHead false \
 && HOME=/root git config --global http.postBuffer 524288000 \
 && HOME=/root git config --global pack.windowMemory "4096m" \
 && apt -y autoremove \
 && apt autoclean \
 && rm -rf /var/cache/apt/* \
 && npm install --global --upgrade yarn \
 && npm cache clean --force \
 && ln -sf /proc/1/fd/1 /var/log/docker.log

COPY build_android.sh build_android.sh

CMD ["/bin/bash", "build_android.sh"]
