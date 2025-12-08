#!/usr/bin/env bash
# stopbmitune.sh for atv/cox
# 2025.12.1

set -euo pipefail

# --- arguments ---
atvHost="${1:-}"
if [ -z "$atvHost" ]; then
  echo "Usage: $0 <atvHost>"
  exit 1
fi

# --- config (self-contained) ---
pyatvCredentials="/root/.android/.pyatv.conf"
atvRemote="atvremote"

# Delays
PRESS_DELAY=0.2
SHORT_DELAY=0.5
LONG_DELAY=8.5
LIVE_MENU_DELAY=2.3

# --- command wrapper ---
atvCmd="$atvRemote --address ${atvHost} --scan-hosts ${atvHost} --storage-filename ${pyatvCredentials}"

log(){ printf "[stopbmitune] %s\n" "$*"; }

press() {
  for key in "$@"; do
    eval "$atvCmd $key" >/dev/null 2>&1 || true
    sleep "${PRESS_DELAY}"
  done
}

doubleclick() {
  local key="$1"
  # Send the same command twice in a single atvremote invocation
  eval "$atvCmd $key $key" >/dev/null 2>&1 || true
}


playingState() { eval "$atvCmd playing" 2>/dev/null || true; }

gotoLiveSearchScreen() {
  press left menu menu
  sleep "${LIVE_MENU_DELAY}"
  press left
  sleep "${SHORT_DELAY}"
  press up
  sleep "${SHORT_DELAY}"
  press select
  sleep "${LIVE_MENU_DELAY}"
}

forceQuitAndArm() {
  # Force quit Cox via app switcher and return to LIVE alphanumeric search in Cox app
  echo "📺 Force quit back to the LIVE alphanumeric search menu in Cox app"

  
  # First issue a dummy Launch Cox to make it the last used in the switcher
  echo "🚀 Launching Cox Contour App..."
  eval "$atvCmd launch_app=com.cox.contour" >/dev/null 2>&1 || true
  sleep "$SHORT_DELAY"

  # Step 1: Open app switcher with double home click, then force-quit Contour
  echo "🔁 Opening app switcher..."
  doubleclick home
  sleep "$SHORT_DELAY"

  echo "🎯 Do a bunch of force quits - cox app should be first)..."

  i=1
  while [ "$i" -le 5 ]; do
  
    # setting the loop to 5 to close extra inadvertent open apps, Cox should be first to close
    echo "🧹 Swiping up to force-quit open apps... (Pass $i)"
    doubleclick up
    sleep "$SHORT_DELAY"
    i=$((i + 1))
  done

  echo "🏡 Returning to UI screen..."
  press home
  sleep "$SHORT_DELAY"

  # Step 2: Launch Cox Contour app and navigate back to Live Section / Search
  echo "🚀 Launching Cox Contour App..."
  eval "$atvCmd launch_app=com.cox.contour" >/dev/null 2>&1 || true
  sleep "$LONG_DELAY"

  press left
  sleep "$LIVE_MENU_DELAY"

  press down
  sleep "$LIVE_MENU_DELAY"
  sleep "$LIVE_MENU_DELAY"

  press right
  sleep "$LIVE_MENU_DELAY"
  sleep "$LIVE_MENU_DELAY"

  press left
  sleep "$LIVE_MENU_DELAY"

  press up
  sleep "$LIVE_MENU_DELAY"

  press select
  sleep "$LIVE_MENU_DELAY"

  echo "✅ Done. App is in alphanumeric search-ready state."
}

log "Cleaning up on ${atvHost}…"
if playingState | grep -q "Device state: Playing"; then
  log "The channel was live in playback → navigating back to Search…"
  gotoLiveSearchScreen
else
  log "Not in playback → ensuring app in known state and in LIVE Search…"
  forceQuitAndArm
fi
log "✅ Cleanup complete."
