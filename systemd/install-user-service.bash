#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cp "$DIR/wl2k.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload

echo "Installed. Start with 'systemctl --user start wl2k'"