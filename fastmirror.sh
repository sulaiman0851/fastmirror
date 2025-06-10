#!/bin/bash
TARGET_PATH="/etc/pacman.d/mirrorlist"
BACKUP_PATH="/etc/pacman.d/mirrorlist.bak"
TMP_FILE="/tmp/mirrorlist"

MIRROR_URL="https://archlinux.org/mirrorlist/?country=ID&protocol=http&protocol=https&ip_version=4"

echo "[*] Fetching mirrorlist from Arch Linux..."
curl -sSL "$MIRROR_URL" -o "$TMP_FILE"

if [[ $? -ne 0 ]]; then
    echo "[!] ERROR: mirrorlist retrieval failed. please check your connection."
    exit 1
fi

echo "[*] Activate all selectec mirror..."
sed -i 's/^#Server/Server/' "$TMP_FILE"

if [[ -f "$TARGET_PATH" ]]; then
    echo "[*] Creating backup: $BACKUP_PATH"
    cp "$TARGET_PATH" "$BACKUP_PATH"
fi

echo "[*] Copying new mirrorlist to $TARGET_PATH..."
cp "$TMP_FILE" "$TARGET_PATH"

if [[ $? -eq 0 ]]; then
    echo "[✔] Mirrorlist updated successfully and backup created!"
else
    echo "[!] File copy failed. Check whether the system is in read-only mode or requires sudo/root."
    exit 1
fi
