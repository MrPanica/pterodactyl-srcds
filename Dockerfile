# =============================================================================
# Pterodactyl Game Server Image — Source Engine / Ubuntu 24.04 Noble
# Optimized for: TF2, CS:S, GMod, L4D2, Insurgency and other SRCDS games
# Author: Custom build
# Base: ubuntu:24.04 (Noble Numbat) LTS — support until April 2029
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="custom"
LABEL description="Pterodactyl Source Engine image — Ubuntu 24.04, optimized for game servers"
LABEL org.opencontainers.image.base.name="ubuntu:24.04"

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container \
    # Steam / SRCDS tweaks
    STEAMCMD_DIR=/home/container/steamcmd \
    LD_LIBRARY_PATH=/home/container/linux64:/home/container/bin:/home/container \
    # Locale
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# -----------------------------------------------------------------------------
# 1. System base + locale
# -----------------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        locales \
        ca-certificates \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Enable i386 (32-bit) architecture — required for SRCDS and SteamCMD
# -----------------------------------------------------------------------------
RUN dpkg --add-architecture i386 && \
    apt-get update -y

# -----------------------------------------------------------------------------
# 3. Install all dependencies
#    32-bit libs: required by srcds_linux (TF2/CSS/GMod still ship 32-bit bins)
#    64-bit libs: for newer/hybrid servers and extensions
#    Tools: tini (PID1), curl, wget, tar, file, lsof, net-tools
# -----------------------------------------------------------------------------
RUN apt-get install -y --no-install-recommends \
    # --- Core tools ---
    tini \
    curl \
    wget \
    xz-utils \
    tar \
    bzip2 \
    unzip \
    git \
    file \
    lsof \
    procps \
    # --- Locale / timezone ---
    tzdata \
    # --- 32-bit runtime essentials for SteamCMD & SRCDS ---
    lib32gcc-s1 \
    lib32stdc++6 \
    libc6-i386 \
    libcurl4-gnutls-dev:i386 \
    # --- 32-bit libs frequently required by SRCDS extensions/plugins ---
    libncurses6:i386 \
    libtinfo6:i386 \
    libz1:i386 \
    libsdl2-2.0-0:i386 \
    libopenal1:i386 \
    libfontconfig1:i386 \
    libfreetype6:i386 \
    libnss3:i386 \
    # --- 64-bit libs (for 64-bit servers / extensions / SourceMod natives) ---
    libncurses6 \
    libtinfo6 \
    libsdl2-2.0-0 \
    libopenal1 \
    libfontconfig1 \
    libfreetype6 \
    libcurl4-gnutls-dev \
    libgcc-s1 \
    libstdc++6 \
    # --- Network / diagnostics tools ---
    iputils-ping \
    net-tools \
    dnsutils \
    iproute2 \
    # --- Python (used by some game server scripts) ---
    python3 \
    python3-pip \
    # --- rcon-cli for remote server management ---
    && RCON_VERSION="0.10.3" \
    && curl -sSL "https://github.com/gorcon/rcon-cli/releases/download/v${RCON_VERSION}/rcon-${RCON_VERSION}-amd64_linux.tar.gz" \
        -o /tmp/rcon.tar.gz \
    && tar xvf /tmp/rcon.tar.gz -C /tmp/ \
    && mv /tmp/rcon-${RCON_VERSION}-amd64_linux/rcon /usr/local/bin/rcon \
    && chmod +x /usr/local/bin/rcon \
    && rm -rf /tmp/rcon* \
    # --- Cleanup ---
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# 4. Network performance tuning
#    Note: sysctl inside Docker requires --privileged or host sysctl tuning.
#    We ship the config file so operators can apply it on the host / at startup.
#    Inside the container we set what we can via limits.conf.
# -----------------------------------------------------------------------------
COPY sysctl-gameserver.conf /etc/sysctl.d/99-gameserver.conf
COPY limits-gameserver.conf /etc/security/limits.d/99-gameserver.conf

# -----------------------------------------------------------------------------
# 5. Create Pterodactyl required user "container"
#    - Home at /home/container (Pterodactyl mounts server data here)
#    - UID/GID 1000 by default
# -----------------------------------------------------------------------------
RUN useradd -m -d /home/container -s /bin/bash container && \
    # Pre-create steamcmd dir with correct ownership
    mkdir -p /home/container/steamcmd && \
    chown -R container:container /home/container

# -----------------------------------------------------------------------------
# 6. Copy entrypoint
# -----------------------------------------------------------------------------
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# -----------------------------------------------------------------------------
# 7. Finalise
# -----------------------------------------------------------------------------
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

STOPSIGNAL SIGINT

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
