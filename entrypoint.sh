#!/bin/bash
# =============================================================================
# Pterodactyl Entrypoint — Source Engine / Ubuntu 24.04
# Compatible with Pterodactyl Wings
# =============================================================================

# ---- Colour helpers ----------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }

# ---- Startup banner ----------------------------------------------------------
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Pterodactyl Source Engine — Ubuntu 24.04 Image    ║"
echo "║   TF2 / CS:S / GMod / L4D2 / SRCDS optimized        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ---- Move to working directory -----------------------------------------------
cd /home/container || { error "Cannot cd to /home/container"; exit 1; }

# ---- Apply network/file-descriptor tweaks (best-effort inside container) ----
# These succeed only if the container has the capability; fail silently.
ulimit -n 65536 2>/dev/null || true

# ---- SteamCMD auto-update ----------------------------------------------------
# SRCDS_APPID: Steam AppID to install/update (e.g. 232250 for TF2)
# AUTO_UPDATE:  1 = update on start (default), 0 = skip
# STEAM_USER / STEAM_PASS / STEAM_AUTH: leave blank for anonymous login
# SRCDS_BETAID / SRCDS_BETAPASS: optional beta branch

if [[ "${AUTO_UPDATE}" == "1" ]] || [[ -z "${AUTO_UPDATE}" ]]; then
    if [[ -n "${SRCDS_APPID}" ]]; then
        info "Checking / updating SteamCMD …"

        # Bootstrap SteamCMD if not present
        STEAMCMD="${HOME}/steamcmd/steamcmd.sh"
        if [[ ! -f "${STEAMCMD}" ]]; then
            info "SteamCMD not found — downloading …"
            mkdir -p "${HOME}/steamcmd"
            curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
                | tar -xz -C "${HOME}/steamcmd/"
            ok "SteamCMD downloaded."
        fi

        # Build login string
        if [[ -z "${STEAM_USER}" ]]; then
            STEAM_LOGIN="anonymous"
        else
            STEAM_LOGIN="${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH}"
        fi

        # Build beta flags
        BETA_FLAGS=""
        [[ -n "${SRCDS_BETAID}" ]]   && BETA_FLAGS+="-beta ${SRCDS_BETAID} "
        [[ -n "${SRCDS_BETAPASS}" ]] && BETA_FLAGS+="-betapassword ${SRCDS_BETAPASS} "

        # Build validate flag
        VALIDATE_FLAG=""
        [[ "${VALIDATE}" == "1" ]] && VALIDATE_FLAG="validate"

        # HLDS mod config (GoldSrc games)
        HLDS_FLAG=""
        [[ -n "${HLDS_GAME}" ]] && HLDS_FLAG="+app_set_config 90 mod ${HLDS_GAME}"

        info "Running SteamCMD update for AppID ${SRCDS_APPID} …"
        # shellcheck disable=SC2086
        "${STEAMCMD}" \
            +force_install_dir /home/container \
            +login ${STEAM_LOGIN} \
            ${HLDS_FLAG} \
            +app_update "${SRCDS_APPID}" ${BETA_FLAGS} ${VALIDATE_FLAG} \
            +quit

        STEAM_EXIT=$?
        if [[ ${STEAM_EXIT} -ne 0 ]]; then
            warn "SteamCMD exited with code ${STEAM_EXIT} — server may be outdated."
        else
            ok "SteamCMD update complete."
        fi
    else
        warn "No SRCDS_APPID set — skipping SteamCMD update, starting server directly."
    fi
else
    info "AUTO_UPDATE=0 — skipping SteamCMD update."
fi

# ---- SourceMod / Metamod auto-install (optional) ----------------------------
# Set SOURCEMOD=1 to auto-install/update Metamod:Source + SourceMod
# Set SM_GAME to the game folder name (tf, cstrike, garrysmod, left4dead2 …)
if [[ "${SOURCEMOD}" == "1" ]] && [[ -n "${SM_GAME}" ]]; then
    info "Checking SourceMod / Metamod:Source for game: ${SM_GAME}"

    SM_DIR="/home/container/${SM_GAME}/addons"
    mkdir -p "${SM_DIR}"

    # --- Metamod:Source ---
    MM_VER="${MM_VERSION:-1.12}"
    MM_URL="https://mms.alliedmods.net/mmsdrop/${MM_VER}/mmsource-latest-linux"
    info "Downloading Metamod:Source ${MM_VER} …"
    curl -sSL "${MM_URL}" | tar -xz -C "${SM_DIR}/" 2>/dev/null \
        && ok "Metamod:Source installed." \
        || warn "Metamod:Source download failed — check MM_VERSION."

    # --- SourceMod ---
    SM_VER="${SM_VERSION:-1.12}"
    SM_URL="https://sm.alliedmods.net/smdrop/${SM_VER}/sourcemod-latest-linux"
    info "Downloading SourceMod ${SM_VER} …"
    curl -sSL "${SM_URL}" | tar -xz -C "${SM_DIR}/" 2>/dev/null \
        && ok "SourceMod installed." \
        || warn "SourceMod download failed — check SM_VERSION."
fi

# ---- Parse and execute startup command (Pterodactyl passes it via $STARTUP) --
if [[ -z "${STARTUP}" ]]; then
    error "No STARTUP command provided by Pterodactyl — cannot start server."
    exit 1
fi

# Replace {{VAR}} template placeholders with actual environment variables
PARSED="${STARTUP}"
while IFS= read -r -d '' VAR; do
    KEY="${VAR%%=*}"
    VAL="${VAR#*=}"
    PARSED="${PARSED//\{\{${KEY}\}\}/${VAL}}"
done < <(env -0)

# Print the final command (Pterodactyl-style prefix)
printf "\n${YELLOW}container@pterodactyl~${RESET} %s\n\n" "${PARSED}"

# Execute — use eval so pipes/redirects in STARTUP work correctly
# shellcheck disable=SC2086
eval ${PARSED}
