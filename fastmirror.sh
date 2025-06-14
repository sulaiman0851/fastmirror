#!/bin/bash

# =============================================
# FastMirror: Auto Update for apt & pacman
# Author: Sulaiman0851
# =============================================

set -e

# ****** [ Color Codes ] ******
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[36m"
NC="\e[0m"

# ****** [ Logger Setup ] ******
# 

LOG_FILE="/var/log/fastmirror.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ****** [ Banner ] ******
echo -e "${BLUE}"
echo "# ============================================="
echo "# FastMirror: Auto Update for apt & pacman"
echo "# Author: Sulaiman0851"
echo "# ============================================="
echo -e "${NC}"

# ****** [ Privilege Check ] ******
if [[ "$EUID" -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
        echo -e "${RED}[!] You must run this script as root or have 'sudo' installed.${NC}"
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# ****** [ GeoIP Mirror Detection ] ******
COUNTRY=$(curl -s https://ipapi.co/country/ || echo "US")
echo -e "${YELLOW}[i] Detected country: $COUNTRY${NC}"

# ****** [ Distro Detection ] ******
DISTRO_ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')

### === DEBIAN/UBUNTU SECTION === ###
if [[ "$DISTRO_ID" =~ ^(debian|ubuntu)$ ]]; then
    echo -e "${GREEN}[APT] Detected Debian/Ubuntu system${NC}"

    echo -e "${YELLOW}[*] Backing up /etc/apt/sources.list...${NC}"
    $SUDO cp /etc/apt/sources.list /etc/apt/sources.list.bak

    echo -e "${YELLOW}[*] Writing optimized mirror list...${NC}"
    cat <<EOF | $SUDO tee /etc/apt/sources.list > /dev/null
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

    echo -e "${GREEN}[✔] sources.list updated!${NC}"

    # ****** [ Check & Offer GPG Install If Missing ] ******
    if ! command -v gpg &>/dev/null; then
        echo -e "${YELLOW}[!] GPG is not installed.${NC}"
        read -p "Do you want to install 'gnupg' now? [Y/n]: " ans
        ans=${ans:-Y}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}[*] Installing gnupg...${NC}"
            $SUDO apt update && $SUDO apt install -y gnupg
        else
            echo -e "${RED}[!] GPG is required to import keys. Aborting.${NC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}[*] Importing required GPG keys...${NC}"
    KEYS=(
        54404762BBB6E853
        BDE6D2B9216EC7A8
        0E98404D386FA1D9
        6ED0E7B82643E131
        F8D2585B783D3481
    )

    for KEY in "${KEYS[@]}"; do
        echo -e "${YELLOW}[KEY] Importing: $KEY${NC}"
        $SUDO gpg --keyserver keyserver.ubuntu.com --recv-keys $KEY || {
            echo -e "${RED}[!] Failed to fetch GPG key: $KEY${NC}"
            exit 1
        }
        $SUDO gpg --export $KEY | $SUDO tee /etc/apt/trusted.gpg.d/$KEY.gpg > /dev/null
    done

    echo -e "${GREEN}[APT] Running apt update...${NC}"
    $SUDO apt update

    echo -e "${GREEN}[✔] APT FastMirror completed!${NC}"

### === ARCH/DERIVATIVE SECTION === ###
elif [[ "$DISTRO_ID" =~ ^(arch|manjaro|endeavouros)$ ]]; then
    echo -e "${GREEN}[PACMAN] Detected Arch-based system${NC}"

    MIRROR_URL="https://archlinux.org/mirrorlist/?country=$COUNTRY&protocol=http&protocol=https&ip_version=4"
    TMP_FILE="/tmp/mirrorlist"
    TARGET_PATH="/etc/pacman.d/mirrorlist"
    BACKUP_PATH="/etc/pacman.d/mirrorlist.bak"

    echo -e "${YELLOW}[*] Fetching mirrorlist from Arch Linux...${NC}"
    curl -sSL "$MIRROR_URL" -o "$TMP_FILE"

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] ERROR: Failed to retrieve mirrorlist.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[*] Enabling all mirror entries...${NC}"
    sed -i 's/^#Server/Server/' "$TMP_FILE"

    if [[ -f "$TARGET_PATH" ]]; then
        echo -e "${YELLOW}[*] Creating backup: $BACKUP_PATH${NC}"
        $SUDO cp "$TARGET_PATH" "$BACKUP_PATH"
    fi

    echo -e "${YELLOW}[*] Copying new mirrorlist to $TARGET_PATH...${NC}"
    $SUDO cp "$TMP_FILE" "$TARGET_PATH"

    echo -e "${YELLOW}[*] Refreshing pacman database...${NC}"
    $SUDO pacman -Syy

    echo -e "${GREEN}[✔] PACMAN FastMirror completed!${NC}"

else
    echo -e "${RED}[✖] Unsupported distro ID: $DISTRO_ID${NC}"
    echo -e "${RED}[!] This script supports Debian, Ubuntu, Arch, Manjaro, EndeavourOS only.${NC}"
    exit 1
fi
