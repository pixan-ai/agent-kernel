#!/usr/bin/env bash
# Shows the latest readable screen of Claude Code. Usage: screen.sh [lines]
# A move along the line becomes a space and any other cursor move a new line; the remaining escape codes are then stripped.
sed -E 's/\x1b\[[0-9]*[CG]/ /g; s/\x1b\[[0-9;]*[HABDEFJKf]/\n/g; s/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b[()][A-Z0-9]//g' /data/tui.log | tr -d '\r' | grep -v '^[[:space:]]*$' | tail -"${1:-30}" | cut -c1-160
