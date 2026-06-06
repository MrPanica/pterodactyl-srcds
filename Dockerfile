FROM ubuntu:24.04

LABEL maintainer="custom"
LABEL description="Pterodactyl Source Engine image for TF2/SRCDS on Ubuntu 24.04"
LABEL org.opencontainers.image.base.name="ubuntu:24.04"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG RCON_VERSION=0.10.3

ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container \
    STEAMCMD_DIR=/home/container/steamcmd \
    LD_LIBRARY_PATH=/home/container/linux64:/home/container/bin:/home/container \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC \
    MALLOC_ARENA_MAX=2

RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        bzip2 \
        ca-certificates \
        curl \
        dnsutils \
        file \
        git \
        iproute2 \
        iputils-ping \
        locales \
        lsof \
        net-tools \
        procps \
        python3 \
        python3-pip \
        tar \
        tini \
        tzdata \
        unzip \
        wget \
        xz-utils \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        libbz2-1.0:i386 \
        libcurl3t64-gnutls:i386 \
        libfreetype6:i386 \
        libgcc-s1:i386 \
        libicu74:i386 \
        libncurses6:i386 \
        libnss3:i386 \
        libopenal1:i386 \
        libsdl2-2.0-0:i386 \
        libssl3t64:i386 \
        libstdc++6:i386 \
        libtinfo6:i386 \
        libunwind8:i386 \
        libuuid1:i386 \
        libz1:i386 \
        libcurl4t64 \
        libfreetype6 \
        libgcc-s1 \
        libicu74 \
        libncurses6 \
        libnss3 \
        libopenal1 \
        libsdl2-2.0-0 \
        libssl3t64 \
        libstdc++6 \
        libtinfo6 \
        libunwind8 \
        libuuid1 \
        libz1; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    curl -fsSL "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_VERSION}/rcon-${RCON_VERSION}-amd64_linux.tar.gz" -o /tmp/rcon.tar.gz; \
    tar -xzf /tmp/rcon.tar.gz -C /tmp; \
    install -m 0755 "/tmp/rcon-${RCON_VERSION}-amd64_linux/rcon" /usr/local/bin/rcon; \
    rm -rf /tmp/rcon*; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY sysctl-gameserver.conf /etc/sysctl.d/99-gameserver.conf
COPY limits-gameserver.conf /etc/security/limits.d/99-gameserver.conf

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN set -eux; \
    useradd -m -d /home/container -s /bin/bash container; \
    mkdir -p /home/container/steamcmd; \
    chown -R container:container /home/container

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

STOPSIGNAL SIGINT

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
