FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG LLVM_VERSION=20

ENV LLVM_VERSION=$LLVM_VERSION

WORKDIR /cmake_build

RUN mkdir -p bin \
 && apt update \
 && apt -y upgrade \
 && apt -y install curl tar zip \
 && curl -L https://apt.llvm.org/llvm-snapshot.gpg.key -o /usr/share/keyrings/llvm-snapshot.gpg.key \
 && echo "deb [signed-by=/usr/share/keyrings/llvm-snapshot.gpg.key] https://apt.llvm.org/bookworm/\
 llvm-toolchain-bookworm-$LLVM_VERSION main" | tee -a /etc/apt/sources.list.d/llvm.list \
 && echo 'alias ll="ls -alF"' >> /root/.bashrc \
 && apt update \
 && apt install -y autoconf autoconf-archive automake build-essential ccache \
    clang-"$LLVM_VERSION" clangd-"$LLVM_VERSION" clang-format-"$LLVM_VERSION" \
    clang-tidy-"$LLVM_VERSION" clang-tools-"$LLVM_VERSION" fonts-liberation2 \
    git-core libgl1-mesa-dev libpulse-dev libqt6opengl6-dev libqt6svg6-dev \
    libssl-dev lld-"$LLVM_VERSION" nasm pkg-config qt6-base-dev \
    qt6-declarative-dev qt6-multimedia-dev qt6-tools-dev-tools qt6-wayland \
 && curl -LO $(curl -s https://api.github.com/repos/ninja-build/ninja/releases/latest \
  | grep "browser_download_url.*linux.zip" | cut -d\" -f4) \
 && unzip ninja-linux.zip -d /usr/local/bin \
 && curl -LO $(curl -s https://api.github.com/repos/Kitware/CMake/releases/latest \
  | grep "browser_download_url.*linux-x86_64.sh" | cut -d\" -f4) \
 && chmod +x cmake-*-linux-x86_64.sh \
 && ./cmake-*-linux-x86_64.sh --prefix=/usr/local --exclude-subdir --skip-license \
 && apt -y autoremove \
 && apt -y clean \
 && rm -rf *.sh *.zip
