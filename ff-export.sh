#!/usr/bin/env bash
set -euo pipefail

# --- Colors ---
C_RESET="\033[0m"
C_INFO="\033[1;34m"
C_OK="\033[1;32m"
C_WARN="\033[1;33m"
C_ERR="\033[1;31m"

# --- Check if Firefox is running ---
if pgrep -x "firefox" &>/dev/null; then
    echo -e "${C_ERR}✗ Firefox läuft noch. Bitte zuerst schließen.${C_RESET}"
    exit 1
fi

echo -e "${C_INFO}→ Firefox-Profil wird gesucht...${C_RESET}"

# --- Find profile directory ---
PROFILE_DIR=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" | head -n 1)

if [[ -z "${PROFILE_DIR}" ]]; then
    echo -e "${C_ERR}✗ Kein Firefox-Profil gefunden.${C_RESET}"
    exit 1
fi
echo -e "${C_OK}✓ Profil gefunden:${C_RESET} ${PROFILE_DIR}"

# --- Backup destination ---
BACKUP_DIR="${HOME}/firefox-backups"
mkdir -p "${BACKUP_DIR}"

# --- Rotation: keep only last 5 backups ---
KEEP=5
mapfile -t OLD_BACKUPS < <(ls -1t "${BACKUP_DIR}"/firefox-profile-*.tar.gz 2>/dev/null)
if (( ${#OLD_BACKUPS[@]} >= KEEP )); then
    for old in "${OLD_BACKUPS[@]:$((KEEP - 1))}"; do
        rm -f "$old"
        echo -e "${C_WARN}⚑ Altes Backup gelöscht:${C_RESET} $old"
    done
fi

# --- Timestamp & archive path ---
TS=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE="${BACKUP_DIR}/firefox-profile-${TS}.tar.gz"

echo -e "${C_INFO}→ Erstelle temporäre Kopie ohne Cache...${C_RESET}"

# --- Temp copy without caches ---
TMP_DIR=$(mktemp -d)
# Ensure cleanup on exit (also on errors)
trap 'rm -rf "${TMP_DIR}"' EXIT

cp -a "${PROFILE_DIR}" "${TMP_DIR}/profile"

# Remove unnecessary directories
rm -rf \
    "${TMP_DIR}/profile/cache2" \
    "${TMP_DIR}/profile/startupCache" \
    "${TMP_DIR}/profile/datareporting" \
    "${TMP_DIR}/profile/crashes" \
    "${TMP_DIR}/profile/sessionstore-backups" \
    "${TMP_DIR}/profile/shader-cache"        # additional GPU cache

echo -e "${C_OK}✓ Caches entfernt${C_RESET}"

echo -e "${C_INFO}→ Erstelle Archiv...${C_RESET}"
tar -czf "${ARCHIVE}" -C "${TMP_DIR}" profile

# --- Verify archive integrity ---
if tar -tzf "${ARCHIVE}" &>/dev/null; then
    echo -e "${C_OK}✓ Archiv verifiziert:${C_RESET} ${ARCHIVE}"
else
    echo -e "${C_ERR}✗ Archiv-Verifikation fehlgeschlagen!${C_RESET}"
    exit 1
fi

# --- Show archive size ---
ARCHIVE_SIZE=$(du -sh "${ARCHIVE}" | cut -f1)
echo -e "${C_OK}✓ Größe:${C_RESET} ${ARCHIVE_SIZE}"
echo -e "${C_OK}✓ Fertig! Archiv liegt unter:${C_RESET} ${ARCHIVE}"
echo -e "${C_INFO}→ Entpacken mit: tar -xzf ${ARCHIVE} -C ~/.mozilla/firefox/${C_RESET}"
