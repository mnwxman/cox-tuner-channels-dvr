#!/usr/bin/env bash

# bmitune.sh for atv/cox (self-contained Bash + Python via -c)
# 2025.12.4
#
# Usage:
#   bmitune.sh "channelName~channelNumber" <atvHost>
# Example:
#   bmitune.sh "SYFY~1032" 192.168.1.22

set -euo pipefail

# --- arguments ---

channelData="${1:-}"   # "channelName~channelNumber"
atvHost="${2:-}"

if [ -z "$channelData" ] || [ -z "$atvHost" ]; then
  echo "Usage: $0 \"channelName~channelNumber\" <atvHost>"
  exit 1
fi

logprefix="[bmitune]"

# --- parse channelName and channelNumber from $1 (bnhf-style) ---

channelName="${channelData%%~*}"
channelNumber="${channelData##*~}"

if [ -z "$channelName" ] || [ -z "$channelNumber" ]; then
  echo "$logprefix ❌ Invalid channel data format. Expected: \"channelName~channelNumber\""
  exit 2
fi

echo "$logprefix Starting tuning for: $channelName ($channelNumber)"

# --- Derive short numeric sequence for alphanumeric entry ---
# Rule: always drop the most significant digit, then strip leading zeros.
# Examples:
#   1055 -> 055 -> 55
#   3200 -> 200
#   6542 -> 542
#   9675 -> 675
#   6034 -> 034 -> 34

# Drop the first character if there is more than one digit
if [ "${#channelNumber}" -gt 1 ]; then
  tmp="${channelNumber:1}"
else
  tmp="$channelNumber"
fi

# Strip leading zeros from the remainder
shortNumber="$(echo "$tmp" | sed 's/^0*//')"
[ -z "$shortNumber" ] && shortNumber="0"

echo "$logprefix Tuning $channelName -> channel number $channelNumber -> typing $shortNumber"


# --- Export values for Python code ---

export ATV_HOST="$atvHost"
export SHORT_NUMBER="$shortNumber"
export CHANNEL_NAME="$channelName"

# --- Python tuning core as a single string, executed with python3 -c ---
# Important: use only double quotes inside the Python code to avoid breaking the Bash single-quoted string. [attached_file:49]

python_code='import asyncio
import json
import os
import sys
from pyatv import connect, scan
from pyatv.const import Protocol

DEVICE_IP = os.environ.get("ATV_HOST")
short_number = os.environ.get("SHORT_NUMBER")
channel_name = os.environ.get("CHANNEL_NAME")

if not DEVICE_IP or not short_number:
    print("❌ Missing required environment (ATV_HOST or SHORT_NUMBER)")
    sys.exit(1)

STORAGE_FILE = "/root/.android/.pyatv.conf"
VALID_PROTOCOLS = {"companion", "mrp"}

async def main() -> None:
    loop = asyncio.get_event_loop()

    atvs = await scan(loop=loop, hosts=[DEVICE_IP])
    conf = next((x for x in atvs if x.address.exploded == DEVICE_IP), None)
    if not conf:
        print("❌ Apple TV not found")
        sys.exit(1)

    try:
        with open(STORAGE_FILE, "r") as f:
            raw = json.load(f)
    except FileNotFoundError:
        print(f"❌ Credentials file not found: {STORAGE_FILE}")
        sys.exit(1)

    try:
        protocols = raw["devices"][0]["protocols"]
    except (KeyError, IndexError, TypeError):
        print("❌ Invalid credentials file format")
        sys.exit(1)

    for proto_name, entry in protocols.items():
        if "credentials" in entry and proto_name.lower() in VALID_PROTOCOLS:
            proto = getattr(Protocol, proto_name.capitalize())
            conf.set_credentials(proto, entry["credentials"])

    atv = await connect(conf, loop=loop)
    try:
        context_info = f"[Name: {channel_name}]" if channel_name else ""
        print(f"💬 Typing channel number \"{short_number}\"... {context_info}")

        await atv.keyboard.text_set(short_number)

        await asyncio.sleep(3)

        print("➡ Navigating to search result...")
        for _ in range(6):
            await atv.remote_control.right()
            await asyncio.sleep(0.6)

        print("▶️ Sending Play command...")
        await atv.remote_control.play_pause()

        print(f"✅ Done tuning to channel {short_number}. {context_info}")
    finally:
        atv.close()

if __name__ == "__main__":
    asyncio.run(main())'

if ! python3 -c "$python_code"; then
  echo "$logprefix ❌ Python tuning block failed for $channelName ($channelNumber)"
  exit 1
fi

echo "$logprefix ✅ Tuning complete for $channelName ($channelNumber)"
exit 0
