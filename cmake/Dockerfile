FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /cmake_build

RUN mkdir -p bin \
 && apt update \
 && apt -y upgrade \
 && apt -y install curl \
 && curl -L https://apt.llvm.org/llvm-snapshot.gpg.key -o /usr/share/keyrings/llvm-snapshot.gpg.key \
 && echo "deb [signed-by=/usr/share/keyrings/llvm-snapshot.gpg.key] https://apt.llvm.org/bookworm/\
 llvm-toolchain-bookworm-18 main" | tee -a /etc/apt/sources.list.d/llvm.list \
 && echo 'alias ll="ls -alF"' >> /root/.bashrc \
 && apt update \
 && apt install -y autoconf autoconf-archive automake build-essential ccache \
    clang-18 clangd-18 clang-format-18 clang-tidy-18 fonts-liberation2 \
    git-core libgl1-mesa-dev libpulse-dev libssl-dev lld-18 nasm pkg-config \
    qt6-base-dev qt6-tools-dev-tools qt6-wayland tar unzip zip \
 && curl -LO $(curl -s https://api.github.com/repos/ninja-build/ninja/releases/latest \
  | grep "browser_download_url.*linux.zip" | cut -d\" -f4) \
 && unzip ninja-linux.zip -d /usr/local/bin \
 && git clone https://github.com/Kitware/CMake.git \
 && cd CMake && ./bootstrap && make && make install && cd - >/dev/null \
 && apt -y autoremove \
 && apt autoclean \
 && rm -rf /var/cache/apt/* CMake *.zip \
 && ln -sf /proc/1/fd/1 /var/log/docker.log

