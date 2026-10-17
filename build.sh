#!/usr/bin/env bash
# Build the watch face for the Forerunner 165 Music.
#   ./build.sh           build bin/GalaxyAnalog.prg
#   ./build.sh run       build and launch in the simulator
#   ./build.sh export    build bin/GalaxyAnalog.iq for the Connect IQ store
set -euo pipefail

cd "$(dirname "$0")"
SDK="$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)"
SDK="${SDK%/}"
KEY="${GARMIN_DEV_KEY:-$HOME/Dropbox/Various/garmin_developer_key}"
DEVICE=fr165m
mkdir -p bin

case "${1:-build}" in
    export)
        "$SDK/bin/monkeyc" -e -f monkey.jungle -o bin/GalaxyAnalog.iq -y "$KEY" -w -r
        ;;
    run)
        "$SDK/bin/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/GalaxyAnalog.prg -y "$KEY" -w
        pgrep -x simulator >/dev/null || { "$SDK/bin/connectiq" & sleep 4; }
        "$SDK/bin/monkeydo" bin/GalaxyAnalog.prg "$DEVICE"
        ;;
    *)
        "$SDK/bin/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/GalaxyAnalog.prg -y "$KEY" -w
        ;;
esac
