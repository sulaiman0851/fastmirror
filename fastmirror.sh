#!/bin/bash

# =============================================
# FastMirror: Auto Update for apt & pacman
# Author: Sulaiman0851
# =============================================

### === DEBIAN/UBUNTU SECTION === ###
APT_SOURCES="/etc/apt/sources.list"
APT_SOURCES_BAK="/etc/apt/sources.list.bak"

APT_NEW_SOURCES=$(cat <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
EOF
)

echo "[APT] Backing up existing sources.list..."
if [[ -f "$APT_SOURCES" ]]; then
    sudo cp "$APT_SOURCES" "$APT_SOURCES_BAK"
    echo "[✓] Backup created: $APT_SOURCES_BAK"
fi

echo "[APT] Updating sources.list with new mirrors..."
echo "$APT_NEW_SOURCES" | sudo tee "$APT_SOURCES" > /dev/null
echo "[✓] sources.list updated successfully!"

# === GPG KEYS FIX === #
APT_KEYS=(
    54404762BBB6E853
    BDE6D2B9216EC7A8
    0E98404D386FA1D9
    6ED0E7B82643E131
    F8D2585B783D3481
)

echo "[APT] Importing GPG keys (if needed)..."
for key in "${APT_KEYS[@]}"; do
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "$key"
done

echo "[APT] Running apt update..."
sudo apt update


### === ARCHLINUX SECTION === ###
PACMAN_TARGET="/etc/pacman.d/mirrorlist"
PACMAN_BACKUP="/etc/pacman.d/mirrorlist.bak"
PACMAN_TMP="/tmp/mirrorlist"
ARCH_MIRROR="https://archlinux.org/mirrorlist/?country=ID&protocol=http&protocol=https&ip_version=4"

if [[ -d "/etc/pacman.d" ]]; then
    echo "[PACMAN] Fetching mirrorlist from Arch Linux..."
    curl -sSL "$ARCH_MIRROR" -o "$PACMAN_TMP"

    if [[ $? -ne 0 ]]; then
        echo "[!] Failed to fetch Arch mirrorlist. Skipping..."
    else
        echo "[PACMAN] Activating all mirrors..."
        sed -i 's/^#Server/Server/' "$PACMAN_TMP"

        if [[ -f "$PACMAN_TARGET" ]]; then
            echo "[PACMAN] Backup created: $PACMAN_BACKUP"
            sudo cp "$PACMAN_TARGET" "$PACMAN_BACKUP"
        fi

        echo "[PACMAN] Replacing mirrorlist..."
        sudo cp "$PACMAN_TMP" "$PACMAN_TARGET"

        if [[ $? -eq 0 ]]; then
            echo "[✓] Pacman mirrorlist updated successfully!"
        else
            echo "[!] Failed to copy new mirrorlist for pacman."
        fi
    fi
fi

echo "🎉 FastMirror completed!"
